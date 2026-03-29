import Foundation
import Network

// MARK: - REST API Service

@MainActor
final class APIService: ObservableObject {
    static let shared = APIService()

    // MARK: - Published State

    @Published private(set) var isRunning = false
    @Published var port: UInt16 = 8765

    // MARK: - Private State

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.chronicle.api.listener", qos: .userInitiated)

    // Rate limiting: 60 req/min per IP
    private let rateLimitMax = 60
    private var rateLimitWindow: [String: [Date]] = [:]
    private let rateLimitLock = NSLock()

    // MARK: - init

    private init() {}

    // MARK: - Server Control

    func start() throws {
        guard !isRunning else { return }

        // Ensure API key exists
        if APIKeyService.shared.storedKey == nil {
            _ = APIKeyService.shared.generateKey()
        }

        // R19: Network security - localhost-only API server
        // No external network calls except iCloud. This server is local-only.
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw APIServiceError.invalidPort
        }

        listener = try NWListener(using: params, on: nwPort)
        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isRunning = true
                case .failed, .cancelled:
                    self?.isRunning = false
                default:
                    break
                }
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: self.queue)
        isRunning = true
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    nonisolated private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                self.receiveRequest(on: connection)
            }
        }
        connection.start(queue: self.queue)
    }

    nonisolated private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self,
                  let data = data,
                  error == nil else {
                connection.cancel()
                return
            }

            Task { @MainActor in
                self.processRequest(data: data, connection: connection)
            }

            if isComplete {
                connection.cancel()
            }
        }
    }

    // MARK: - API Key

    nonisolated var apiKey: String? {
        APIKeyService.shared.storedKey
    }

    nonisolated var hasAPIKey: Bool {
        APIKeyService.shared.hasKey
    }

    @discardableResult
    func regenerateAPIKey() -> String {
        APIKeyService.shared.deleteKey()
        return APIKeyService.shared.generateKey()
    }

    // MARK: - Request Processing

    private func processRequest(data: Data, connection: NWConnection) {
        guard let rawRequest = String(data: data, encoding: .utf8) else {
            sendError(status: .badRequest, message: "Malformed request", connection: connection)
            return
        }

        let lines = rawRequest.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendError(status: .badRequest, message: "Empty request", connection: connection)
            return
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendError(status: .badRequest, message: "Invalid request line", connection: connection)
            return
        }

        let method = String(parts[0])
        let path = String(parts[1])

        // Extract headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            let headerParts = line.split(separator: ":", maxSplits: 1)
            if headerParts.count == 2 {
                let key = headerParts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let value = headerParts[1].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        // Extract body (everything after the double \r\n)
        var body = ""
        if let doubleCrlfRange = rawRequest.range(of: "\r\n\r\n") {
            body = String(rawRequest[doubleCrlfRange.upperBound...])
        }

        // Rate limiting
        let clientIP = connection.endpoint.debugDescription
        if !checkRateLimit(for: clientIP) {
            sendError(status: .tooManyRequests, message: "Rate limit exceeded. 60 requests/minute.", connection: connection)
            return
        }

        // Auth check (skip for /health and /openapi.json)
        if path != "/health" && path != "/openapi.json" {
            let authHeader = headers["authorization"] ?? headers["x-api-key"] ?? ""
            let token: String
            if authHeader.lowercased().hasPrefix("bearer ") {
                token = String(authHeader.dropFirst(7))
            } else {
                token = authHeader
            }

            if token.isEmpty || !APIKeyService.shared.validate(token) {
                sendError(status: .unauthorized, message: "Invalid or missing API key", connection: connection)
                return
            }

            // R19: TOTP 2FA check - require X-TOTP header if 2FA is enabled
            if TOTPService.shared.isEnabled {
                let totpHeader = headers["x-totp"] ?? ""
                if !TOTPService.shared.verifyCode(totpHeader) {
                    sendError(status: .unauthorized, message: "Invalid or missing TOTP code. Enable 2FA in API settings.", connection: connection)
                    return
                }
            }
        }

        // Route
        route(method: method, path: path, body: body, connection: connection)
    }

    // MARK: - Routing

    private func route(method: String, path: String, body: String, connection: NWConnection) {
        let billStore = BillStore.shared
        let householdService = HouseholdService.shared

        // Parse bill ID from path
        let pathComponents = path.split(separator: "/").map(String.init)

        switch (method, path) {
        // ---- Bills ----
        case ("GET", "/bills"):
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(billStore.bills),
               let json = String(data: data, encoding: .utf8) {
                sendJSON(status: .ok, body: json, connection: connection)
            } else {
                sendJSON(status: .ok, body: "[]", connection: connection)
            }

        case ("POST", "/bills"):
            guard let jsonData = body.data(using: .utf8) else {
                sendError(status: .badRequest, message: "Invalid JSON body", connection: connection)
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                let newBill = try decoder.decode(Bill.self, from: jsonData)
                // Create bill with fresh ID and timestamp
                let bill = Bill(
                    id: UUID(),
                    name: newBill.name,
                    amountCents: newBill.amountCents,
                    currency: newBill.currency,
                    dueDay: newBill.dueDay,
                    dueDate: newBill.dueDate,
                    recurrence: newBill.recurrence,
                    category: newBill.category,
                    notes: newBill.notes,
                    reminderTimings: newBill.reminderTimings,
                    autoMarkPaid: newBill.autoMarkPaid,
                    isActive: newBill.isActive,
                    isPaid: newBill.isPaid,
                    ownerId: newBill.ownerId,
                    createdAt: Date(),
                    isTaxDeductible: newBill.isTaxDeductible,
                    businessTag: newBill.businessTag,
                    isReimbursable: newBill.isReimbursable,
                    invoiceReference: newBill.invoiceReference,
                    attachedInvoiceURL: newBill.attachedInvoiceURL,
                    originalAmount: newBill.originalAmount,
                    originalCurrency: newBill.originalCurrency,
                    receiptURL: newBill.receiptURL
                )
                billStore.addBill(bill)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(bill),
                   let json = String(data: data, encoding: .utf8) {
                    sendJSON(status: .created, body: json, connection: connection)
                } else {
                    sendSuccess(status: .created, message: "Bill created", connection: connection)
                }
            } catch {
                sendError(status: .badRequest, message: "Failed to parse bill: \(error.localizedDescription)", connection: connection)
            }

        case ("GET", _) where pathComponents.count == 2 && pathComponents[0] == "bills":
            let idStr = pathComponents[1]
            guard let id = UUID(uuidString: idStr) else {
                sendError(status: .badRequest, message: "Invalid bill ID", connection: connection)
                return
            }
            if let bill = billStore.bills.first(where: { $0.id == id }) {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(bill),
                   let json = String(data: data, encoding: .utf8) {
                    sendJSON(status: .ok, body: json, connection: connection)
                }
            } else {
                sendError(status: .notFound, message: "Bill not found", connection: connection)
            }

        case ("PUT", _) where pathComponents.count == 2 && pathComponents[0] == "bills":
            let idStr = pathComponents[1]
            guard let id = UUID(uuidString: idStr) else {
                sendError(status: .badRequest, message: "Invalid bill ID", connection: connection)
                return
            }
            guard var bill = billStore.bills.first(where: { $0.id == id }) else {
                sendError(status: .notFound, message: "Bill not found", connection: connection)
                return
            }
            guard let jsonData = body.data(using: .utf8) else {
                sendError(status: .badRequest, message: "Invalid JSON body", connection: connection)
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                let updates = try decoder.decode(BillUpdate.self, from: jsonData)
                bill.name = updates.name ?? bill.name
                bill.amountCents = updates.amountCents ?? bill.amountCents
                bill.currency = updates.currency ?? bill.currency
                bill.dueDay = updates.dueDay ?? bill.dueDay
                bill.dueDate = updates.dueDate ?? bill.dueDate
                bill.recurrence = updates.recurrence ?? bill.recurrence
                bill.category = updates.category ?? bill.category
                bill.notes = updates.notes ?? bill.notes
                bill.autoMarkPaid = updates.autoMarkPaid ?? bill.autoMarkPaid
                bill.isTaxDeductible = updates.isTaxDeductible ?? bill.isTaxDeductible
                bill.businessTag = updates.businessTag ?? bill.businessTag
                bill.isReimbursable = updates.isReimbursable ?? bill.isReimbursable
                bill.invoiceReference = updates.invoiceReference ?? bill.invoiceReference
                bill.isActive = updates.isActive ?? bill.isActive
                bill.isPaid = updates.isPaid ?? bill.isPaid
                billStore.updateBill(bill)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(bill),
                   let json = String(data: data, encoding: .utf8) {
                    sendJSON(status: .ok, body: json, connection: connection)
                }
            } catch {
                sendError(status: .badRequest, message: "Failed to parse bill update: \(error.localizedDescription)", connection: connection)
            }

        case ("DELETE", _) where pathComponents.count == 2 && pathComponents[0] == "bills":
            let idStr = pathComponents[1]
            guard let id = UUID(uuidString: idStr) else {
                sendError(status: .badRequest, message: "Invalid bill ID", connection: connection)
                return
            }
            guard billStore.bills.contains(where: { $0.id == id }) else {
                sendError(status: .notFound, message: "Bill not found", connection: connection)
                return
            }
            billStore.deleteBill(id)
            sendSuccess(status: .ok, message: "Bill deleted", connection: connection)

        // ---- Summary ----
        case ("GET", "/summary"):
            let summary = buildSummary(billStore: billStore)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(summary),
               let json = String(data: data, encoding: .utf8) {
                sendJSON(status: .ok, body: json, connection: connection)
            }

        // ---- Household ----
        case ("GET", "/household"):
            if let household = householdService.household {
                let balances = householdService.balances
                let balanceDTOs = balances.map { CodableMemberBalance(
                    id: $0.id,
                    memberId: $0.memberId,
                    memberName: $0.memberName,
                    netBalanceCents: $0.netBalanceCents
                )}
                let response = HouseholdAPIResponseDTO(household: household, balances: balanceDTOs)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(response),
                   let json = String(data: data, encoding: .utf8) {
                    sendJSON(status: .ok, body: json, connection: connection)
                }
            } else {
                sendError(status: .notFound, message: "No household found", connection: connection)
            }

        // ---- Health ----
        case ("GET", "/health"):
            let health: [String: Any] = [
                "status": "ok",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "version": "1.0.0",
                "billsCount": billStore.bills.count,
                "household": householdService.household != nil
            ]
            if let data = try? JSONSerialization.data(withJSONObject: health),
               let json = String(data: data, encoding: .utf8) {
                sendJSON(status: .ok, body: json, connection: connection)
            }

        // ---- OpenAPI ----
        case ("GET", "/openapi.json"):
            let spec = OpenAPISpecLoader.load(port: Int(self.port))
            sendJSON(status: .ok, body: spec, connection: connection)

        // ---- Not Found ----
        default:
            sendError(status: .notFound, message: "Endpoint not found", connection: connection)
        }
    }

    // MARK: - Summary Builder

    private func buildSummary(billStore: BillStore) -> SummaryResponse {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!

        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now))!
        let yearEnd = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: yearStart)!

        let monthlyBills = billStore.bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd }
        let monthlyPaid = monthlyBills.filter { $0.isPaid }
        let monthlyUnpaid = monthlyBills.filter { !$0.isPaid }

        let yearlyBills = billStore.bills.filter { $0.dueDate >= yearStart && $0.dueDate <= yearEnd }
        let yearlyPaid = yearlyBills.filter { $0.isPaid }
        let yearlyUnpaid = yearlyBills.filter { !$0.isPaid }

        let convert = { (bills: [Bill]) -> Decimal in
            bills.reduce(Decimal(0)) { $0 + $1.amount }
        }

        var byCategory: [String: Decimal] = [:]
        for bill in monthlyBills {
            let key = bill.category.rawValue.lowercased()
            byCategory[key, default: 0] += bill.amount
        }

        return SummaryResponse(
            monthly: PeriodSummary(
                total: convert(monthlyBills),
                paid: convert(monthlyPaid),
                unpaid: convert(monthlyUnpaid),
                count: monthlyBills.count
            ),
            yearly: PeriodSummary(
                total: convert(yearlyBills),
                paid: convert(yearlyPaid),
                unpaid: convert(yearlyUnpaid),
                count: yearlyBills.count
            ),
            byCategory: byCategory
        )
    }

    // MARK: - Response Helpers

    private func sendJSON(status: HTTPStatus, body: String, connection: NWConnection) {
        sendResponse(status: status, contentType: "application/json", body: body, connection: connection)
    }

    private func sendError(status: HTTPStatus, message: String, connection: NWConnection) {
        let body = "{\"error\":\"\(message)\"}"
        sendResponse(status: status, contentType: "application/json", body: body, connection: connection)
    }

    private func sendSuccess(status: HTTPStatus, message: String, connection: NWConnection) {
        let body = "{\"message\":\"\(message)\"}"
        sendResponse(status: status, contentType: "application/json", body: body, connection: connection)
    }

    nonisolated private func sendResponse(status: HTTPStatus, contentType: String, body: String, connection: NWConnection) {
        let response = "HTTP/1.1 \(status.code) \(status.text)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Headers: Authorization, X-API-Key, Content-Type\r\nAccess-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\nConnection: close\r\n\r\n\(body)"

        let data = response.data(using: .utf8) ?? Data()
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Rate Limiting

    private func checkRateLimit(for clientId: String) -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-60)

        rateLimitLock.lock()
        defer { rateLimitLock.unlock() }

        var timestamps = rateLimitWindow[clientId] ?? []
        timestamps = timestamps.filter { $0 > windowStart }

        if timestamps.count >= rateLimitMax {
            return false
        }

        timestamps.append(now)
        rateLimitWindow[clientId] = timestamps
        return true
    }

    // MARK: - Restart (nonisolated safe)

    nonisolated func restart(port newPort: UInt16) throws {
        Task { @MainActor in
            self.stop()
            self.port = newPort
            try? self.start()
        }
    }
}

// MARK: - HTTP Status

private enum HTTPStatus {
    case ok, created, badRequest, unauthorized, notFound, tooManyRequests, internalServerError

    var code: Int {
        switch self {
        case .ok: return 200
        case .created: return 201
        case .badRequest: return 400
        case .unauthorized: return 401
        case .notFound: return 404
        case .tooManyRequests: return 429
        case .internalServerError: return 500
        }
    }

    var text: String {
        switch self {
        case .ok: return "OK"
        case .created: return "Created"
        case .badRequest: return "Bad Request"
        case .unauthorized: return "Unauthorized"
        case .notFound: return "Not Found"
        case .tooManyRequests: return "Too Many Requests"
        case .internalServerError: return "Internal Server Error"
        }
    }
}

// MARK: - API Errors

enum APIServiceError: Error, LocalizedError {
    case invalidPort
    case serverNotRunning
    case keychainError(String)

    var errorDescription: String? {
        switch self {
        case .invalidPort: return "Invalid port number"
        case .serverNotRunning: return "API server is not running"
        case .keychainError(let msg): return "Keychain error: \(msg)"
        }
    }
}

// MARK: - Data Transfer Objects

private struct BillUpdate: Codable {
    var name: String?
    var amountCents: Int?
    var currency: Currency?
    var dueDay: Int?
    var dueDate: Date?
    var recurrence: Recurrence?
    var category: Category?
    var notes: String?
    var autoMarkPaid: Bool?
    var isTaxDeductible: Bool?
    var businessTag: BusinessTag?
    var isReimbursable: Bool?
    var invoiceReference: String?
    var isActive: Bool?
    var isPaid: Bool?
}

struct SummaryResponse: Codable {
    let monthly: PeriodSummary
    let yearly: PeriodSummary
    let byCategory: [String: Decimal]
}

struct PeriodSummary: Codable {
    let total: Decimal
    let paid: Decimal
    let unpaid: Decimal
    let count: Int
}

// Codable version of MemberBalance for API responses
private struct CodableMemberBalance: Codable {
    let id: UUID
    let memberId: UUID
    let memberName: String
    let netBalanceCents: Int
}

private struct HouseholdAPIResponseDTO: Codable {
    let household: Household
    let balances: [CodableMemberBalance]
}

// MARK: - OpenAPI Spec Loader

/// Loads openapi.json from the app bundle or falls back to the embedded spec.
enum OpenAPISpecLoader {
    static func load(port: Int) -> String {
        // Try to load from bundle first
        if let url = Bundle.main.url(forResource: "openapi", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let string = String(data: data, encoding: .utf8) {
            // Substitute the port in the server URL
            return string.replacingOccurrences(of: "localhost:8765", with: "localhost:\(port)")
        }
        // Fall back to the embedded minimal spec
        return embeddedSpec(port: port)
    }

    private static func embeddedSpec(port: Int) -> String {
        """
        {
          "openapi": "3.0.0",
          "info": {
            "title": "Chronicle API",
            "version": "1.0.0",
            "description": "REST API for Chronicle Bill Tracker macOS app"
          },
          "servers": [{ "url": "http://localhost:\(port)" }],
          "paths": {
            "/bills": {
              "get": {
                "summary": "List all bills",
                "security": [{ "bearerAuth": [] }],
                "responses": {
                  "200": { "description": "Array of bills" }
                }
              },
              "post": {
                "summary": "Create a bill",
                "security": [{ "bearerAuth": [] }],
                "requestBody": { "content": { "application/json": { "schema": { "$ref": "#/components/schemas/Bill" } } } },
                "responses": {
                  "201": { "description": "Bill created" },
                  "400": { "description": "Invalid JSON body" }
                }
              }
            },
            "/bills/{id}": {
              "get": {
                "summary": "Get bill by ID",
                "security": [{ "bearerAuth": [] }],
                "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string", "format": "uuid" } }],
                "responses": {
                  "200": { "description": "Bill object" },
                  "404": { "description": "Bill not found" }
                }
              },
              "put": {
                "summary": "Update a bill",
                "security": [{ "bearerAuth": [] }],
                "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string", "format": "uuid" } }],
                "requestBody": { "content": { "application/json": { "schema": { "$ref": "#/components/schemas/BillUpdate" } } } },
                "responses": {
                  "200": { "description": "Bill updated" },
                  "404": { "description": "Bill not found" }
                }
              },
              "delete": {
                "summary": "Delete a bill",
                "security": [{ "bearerAuth": [] }],
                "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string", "format": "uuid" } }],
                "responses": {
                  "200": { "description": "Bill deleted" },
                  "404": { "description": "Bill not found" }
                }
              }
            },
            "/summary": {
              "get": {
                "summary": "Get spending summary (monthly and yearly)",
                "security": [{ "bearerAuth": [] }],
                "responses": {
                  "200": { "description": "Summary object", "content": { "application/json": { "schema": { "$ref": "#/components/schemas/SummaryResponse" } } } }
                }
              }
            },
            "/household": {
              "get": {
                "summary": "Get household info and member balances",
                "security": [{ "bearerAuth": [] }],
                "responses": {
                  "200": { "description": "Household response" },
                  "404": { "description": "No household found" }
                }
              }
            },
            "/health": {
              "get": {
                "summary": "Server health check",
                "responses": {
                  "200": { "description": "Server is healthy" }
                }
              }
            },
            "/openapi.json": {
              "get": {
                "summary": "OpenAPI 3.0 specification",
                "responses": {
                  "200": { "description": "OpenAPI JSON document" }
                }
              }
            }
          },
          "components": {
            "securitySchemes": {
              "bearerAuth": {
                "type": "http",
                "scheme": "bearer",
                "bearerFormat": "API key",
                "description": "Enter your Chronicle API key as \\"Authorization: Bearer <key>\\" or \\"X-API-Key: <key>\\"."
              }
            },
            "schemas": {
              "Bill": {
                "type": "object",
                "properties": {
                  "id": { "type": "string", "format": "uuid" },
                  "name": { "type": "string" },
                  "amountCents": { "type": "integer" },
                  "currency": { "type": "string" },
                  "dueDay": { "type": "integer" },
                  "dueDate": { "type": "string", "format": "date-time" },
                  "recurrence": { "type": "string" },
                  "category": { "type": "string" },
                  "notes": { "type": "string", "nullable": true },
                  "isPaid": { "type": "boolean" },
                  "isActive": { "type": "boolean" },
                  "createdAt": { "type": "string", "format": "date-time" }
                }
              },
              "BillUpdate": {
                "type": "object",
                "properties": {
                  "name": { "type": "string" },
                  "amountCents": { "type": "integer" },
                  "dueDate": { "type": "string", "format": "date-time" },
                  "recurrence": { "type": "string" },
                  "category": { "type": "string" },
                  "isPaid": { "type": "boolean" }
                }
              },
              "SummaryResponse": {
                "type": "object",
                "properties": {
                  "monthly": { "$ref": "#/components/schemas/PeriodSummary" },
                  "yearly": { "$ref": "#/components/schemas/PeriodSummary" },
                  "byCategory": { "type": "object", "additionalProperties": { "type": "number" } }
                }
              },
              "PeriodSummary": {
                "type": "object",
                "properties": {
                  "total": { "type": "number" },
                  "paid": { "type": "number" },
                  "unpaid": { "type": "number" },
                  "count": { "type": "integer" }
                }
              }
            }
          }
        }
        """
    }
}
