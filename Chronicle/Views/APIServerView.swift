import SwiftUI

// MARK: - API Server View

struct APIServerView: View {
    @State private var isRunning = false
    @State private var portString = "8765"
    @State private var showAPIKey = false
    @State private var copiedKey = false
    @State private var currentAPIKey: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Text("REST API Server")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Toggle("Server", isOn: $isRunning)
                        .toggleStyle(.switch)
                        .onChange(of: isRunning) { newValue in
                            Task {
                                if newValue {
                                    await startServer()
                                } else {
                                    await stopServer()
                                }
                            }
                        }
                }

                Text("Enable the local API server to access Chronicle data from other apps, scripts, or the web dashboard.")
                    .foregroundColor(.secondary)

                Divider()

                // Server Configuration
                VStack(alignment: .leading, spacing: 16) {
                    Text("Configuration")
                        .font(.headline)

                    HStack {
                        Text("Port:")
                        TextField("Port", text: $portString)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .disabled(isRunning)
                    }

                    HStack {
                        Button("Restart Server") {
                            Task {
                                await restartServer()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isRunning)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                Divider()

                // API Key
                VStack(alignment: .leading, spacing: 16) {
                    Text("API Authentication")
                        .font(.headline)

                    Text("Your API key is required for all requests.")
                        .foregroundColor(.secondary)

                    if let apiKey = currentAPIKey {
                        HStack {
                            if showAPIKey {
                                Text(apiKey)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            } else {
                                Text(String(repeating: "•", count: 40))
                                    .font(.system(.body, design: .monospaced))
                            }

                            Spacer()

                            Button(showAPIKey ? "Hide" : "Show") {
                                showAPIKey.toggle()
                            }
                            .buttonStyle(.bordered)

                            Button("Copy") {
                                copyAPIKey(apiKey)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button("Generate API Key") {
                            currentAPIKey = APIService.shared.generateAPIKey()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                Divider()

                // Endpoints
                VStack(alignment: .leading, spacing: 16) {
                    Text("API Endpoints")
                        .font(.headline)

                    endpointsList
                }

                Divider()

                // Example Usage
                VStack(alignment: .leading, spacing: 16) {
                    Text("Example Usage")
                        .font(.headline)

                    codeBlock("""
                    # Get all bills
                    curl -H "X-API-Key: \(currentAPIKey ?? "YOUR_KEY")" \\
                         http://localhost:\(portString)/bills

                    # Get spending summary
                    curl -H "X-API-Key: \(currentAPIKey ?? "YOUR_KEY")" \\
                         http://localhost:\(portString)/summary

                    # OpenAPI specification
                    http://localhost:\(portString)/openapi.json
                    """)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 600)
        .onAppear {
            portString = String(APIService.shared.port)
            isRunning = APIService.shared.isRunning
            currentAPIKey = APIService.shared.apiKey
        }
    }

    private var endpointsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            endpointRow("GET", "/bills", "List all bills")
            endpointRow("GET", "/bills/:id", "Get bill by ID")
            endpointRow("POST", "/bills", "Create a bill")
            endpointRow("PUT", "/bills/:id", "Update a bill")
            endpointRow("DELETE", "/bills/:id", "Delete a bill")
            endpointRow("GET", "/summary", "Get spending summary")
            endpointRow("GET", "/household", "Get household info")
            endpointRow("GET", "/openapi.json", "OpenAPI 3.0 specification")
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func endpointRow(_ method: String, _ path: String, _ description: String) -> some View {
        HStack {
            Text(method)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(methodColor(method))
                .frame(width: 60, alignment: .leading)

            Text(path)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)

            Spacer()

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return .green
        case "POST": return .blue
        case "PUT": return .orange
        case "DELETE": return .red
        default: return .gray
        }
    }

    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
    }

    // MARK: - Actions

    private func startServer() async {
        do {
            if let port = UInt16(portString) {
                APIService.shared.port = port
                try APIService.shared.start()
            }
        } catch {
            print("Failed to start server: \(error)")
        }
    }

    private func stopServer() async {
        APIService.shared.stop()
    }

    private func restartServer() async {
        do {
            if let port = UInt16(portString) {
                try APIService.shared.restart(port: port)
            }
        } catch {
            print("Failed to restart server: \(error)")
        }
    }

    private func copyAPIKey(_ key: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key, forType: .string)
        copiedKey = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedKey = false
        }
    }
}
