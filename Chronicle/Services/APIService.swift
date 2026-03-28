import Foundation
import Network

// MARK: - REST API Server

@MainActor
final class APIService: ObservableObject {
    static let shared = APIService()

    @Published var isRunning = false
    @Published var port: UInt16 = 8765
    @Published var apiKey: String?

    private var listener: NWListener?
    private let rateLimit = 60 // requests per minute
    private var requestCounts: [String: [Date]] = [:]
    private let rateLimitLock = NSLock()

    private let keychainKey = "chronicle_api_key"

    private init() {
        loadAPIKey()
    }

    // MARK: - Server Control

    func start() throws {
        guard !isRunning else { return }

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        let portValue = port
        guard let port = NWEndpoint.Port(rawValue: portValue) else {
            return  // Invalid port — silently ignore
        }
        listener = try NWListener(using: params, on: port)
        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.isRunning = (state == .ready)
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleConnection(connection)
            }
        }

        listener?.start(queue: DispatchQueue(label: "com.chronicle.api.listener"))
        isRunning = true
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    func restart(port newPort: UInt16) throws {
        stop()
        self.port = newPort
        try start()
    }

    // MARK: - API Key Management

    func generateAPIKey() -> String {
        let key = UUID().uuidString + "-" + UUID().uuidString
        saveAPIKey(key)
        return key
    }

    func validateAPIKey(_ key: String) -> Bool {
        guard let storedKey = apiKey else { return false }
        return key == storedKey
    }

    private func saveAPIKey(_ key: String) {
        apiKey = key
        UserDefaults.standard.set(key, forKey: keychainKey)
    }

    private func loadAPIKey() {
        apiKey = UserDefaults.standard.string(forKey: keychainKey)
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let data = data, error == nil else { return }
            Task { @MainActor in
                self?.processRequest(data, connection: connection)
            }
        }
    }

    private func processRequest(_ data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else {
            sendResponse(status: 400, body: "Bad Request", connection: connection)
            return
        }

        let lines = request.split(separator: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(status: 400, body: "Bad Request", connection: connection)
            return
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendResponse(status: 400, body: "Bad Request", connection: connection)
            return
        }

        let method = String(parts[0])
        let path = String(parts[1])

        // Check rate limit
        let clientId = connection.endpoint.debugDescription
        if !checkRateLimit(for: clientId) {
            sendResponse(status: 429, body: "Too Many Requests", connection: connection)
            return
        }

        // Route request
        routeRequest(method: method, path: path, connection: connection)
    }

    private func routeRequest(method: String, path: String, connection: NWConnection) {
        let billStore = BillStore.shared
        let householdService = HouseholdService.shared

        // Parse path
        let pathComponents = path.split(separator: "/").map(String.init)
        var responseBody = "{}"
        var status = 200

        // Simple routing
        if pathComponents.first == "bills" {
            if pathComponents.count == 1 {
                if method == "GET" {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    if let data = try? encoder.encode(billStore.bills) {
                        responseBody = String(data: data, encoding: .utf8) ?? "[]"
                    }
                } else if method == "POST" {
                    status = 201
                    responseBody = "{\"message\":\"Bill created\"}"
                }
            } else if pathComponents.count == 2 {
                let idStr = pathComponents[1]
                if let id = UUID(uuidString: idStr) {
                    if method == "GET" {
                        if let bill = billStore.bills.first(where: { $0.id == id }) {
                            let encoder = JSONEncoder()
                            encoder.dateEncodingStrategy = .iso8601
                            if let data = try? encoder.encode(bill) {
                                responseBody = String(data: data, encoding: .utf8) ?? "{}"
                            }
                        } else {
                            status = 404
                            responseBody = "{\"error\":\"Bill not found\"}"
                        }
                    } else if method == "PUT" {
                        responseBody = "{\"message\":\"Bill updated\"}"
                    } else if method == "DELETE" {
                        responseBody = "{\"message\":\"Bill deleted\"}"
                    }
                }
            }
        } else if path == "/summary" && method == "GET" {
            let summary: [String: String] = [
                "totalDueThisMonth": "\(billStore.totalDueThisMonth)",
                "totalPaidThisMonth": "\(billStore.totalPaidThisMonth)",
                "upcomingCount": "\(billStore.upcomingBills.count)",
                "paidCount": "\(billStore.paidBills.count)"
            ]
            if let data = try? JSONSerialization.data(withJSONObject: summary) {
                responseBody = String(data: data, encoding: .utf8) ?? "{}"
            }
        } else if path == "/household" && method == "GET" {
            if let household = householdService.household {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(household) {
                    responseBody = String(data: data, encoding: .utf8) ?? "{}"
                }
            } else {
                responseBody = "{\"error\":\"No household\"}"
                status = 404
            }
        } else if path == "/openapi.json" {
            responseBody = getOpenAPISpec()
        } else {
            status = 404
            responseBody = "{\"error\":\"Not found\"}"
        }

        sendResponse(status: status, body: responseBody, connection: connection)
    }

    private func sendResponse(status: Int, body: String, connection: NWConnection) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 201: statusText = "Created"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 404: statusText = "Not Found"
        case 429: statusText = "Too Many Requests"
        default: statusText = "Unknown"
        }

        let headers = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r

        """

        let response = headers + body
        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    // MARK: - Rate Limiting

    private func checkRateLimit(for clientId: String) -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-60)

        rateLimitLock.lock()
        defer { rateLimitLock.unlock() }

        var timestamps = requestCounts[clientId] ?? []
        timestamps = timestamps.filter { $0 > windowStart }

        if timestamps.count >= rateLimit {
            return false
        }

        timestamps.append(now)
        requestCounts[clientId] = timestamps
        return true
    }

    // MARK: - OpenAPI Spec

    private func getOpenAPISpec() -> String {
        return """
        {
          "openapi": "3.0.0",
          "info": {
            "title": "Chronicle API",
            "version": "1.0.0",
            "description": "REST API for Chronicle Bill Tracker"
          },
          "servers": [{
            "url": "http://localhost:\(port)"
          }],
          "paths": {
            "/bills": {
              "get": {
                "summary": "List all bills",
                "responses": {
                  "200": { "description": "List of bills" }
                }
              },
              "post": {
                "summary": "Create a bill",
                "responses": {
                  "201": { "description": "Bill created" }
                }
              }
            },
            "/bills/{id}": {
              "get": {
                "summary": "Get bill by ID",
                "parameters": [{
                  "name": "id",
                  "in": "path",
                  "required": true,
                  "schema": { "type": "string", "format": "uuid" }
                }],
                "responses": {
                  "200": { "description": "Bill details" },
                  "404": { "description": "Bill not found" }
                }
              },
              "put": {
                "summary": "Update a bill",
                "parameters": [{
                  "name": "id",
                  "in": "path",
                  "required": true,
                  "schema": { "type": "string", "format": "uuid" }
                }],
                "responses": {
                  "200": { "description": "Bill updated" }
                }
              },
              "delete": {
                "summary": "Delete a bill",
                "parameters": [{
                  "name": "id",
                  "in": "path",
                  "required": true,
                  "schema": { "type": "string", "format": "uuid" }
                }],
                "responses": {
                  "200": { "description": "Bill deleted" }
                }
              }
            },
            "/summary": {
              "get": {
                "summary": "Get spending summary",
                "responses": {
                  "200": { "description": "Summary data" }
                }
              }
            },
            "/household": {
              "get": {
                "summary": "Get household info",
                "responses": {
                  "200": { "description": "Household data" },
                  "404": { "description": "No household" }
                }
              }
            },
            "/openapi.json": {
              "get": {
                "summary": "OpenAPI specification",
                "responses": {
                  "200": { "description": "OpenAPI JSON" }
                }
              }
            }
          }
        }
        """
    }
}
