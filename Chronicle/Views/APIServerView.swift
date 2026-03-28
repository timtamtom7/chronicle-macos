import SwiftUI

// MARK: - API Server View

struct APIServerView: View {
    @StateObject private var apiService = APIService.shared
    @State private var portString = "8765"
    @State private var showAPIKey = false
    @State private var copiedKey = false
    @State private var currentAPIKey: String?
    @State private var copiedPort: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Text("REST API Server")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Toggle("Server", isOn: Binding(
                        get: { apiService.isRunning },
                        set: { newValue in
                            Task {
                                if newValue {
                                    await startServer()
                                } else {
                                    await stopServer()
                                }
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .accessibilityLabel(apiService.isRunning ? "API server is running. Tap to stop." : "API server is stopped. Tap to start.")
                }

                Text("Enable the local API server to access Chronicle data from other apps, scripts, or the web dashboard.")
                    .foregroundColor(Theme.textSecondary)

                Divider()

                // Server Status
                if apiService.isRunning {
                    HStack {
                        Circle()
                            .fill(Theme.success)
                            .frame(width: 8, height: 8)
                        Text("Server running at http://localhost:\(portString)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        Spacer()

                        Button("Open API Docs") {
                            openAPIDocs()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                    .padding(12)
                    .background(Theme.success.opacity(0.1))
                    .cornerRadius(Theme.radiusSmall)
                } else {
                    HStack {
                        Circle()
                            .fill(Theme.danger)
                            .frame(width: 8, height: 8)
                        Text("Server stopped")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(12)
                    .background(Theme.danger.opacity(0.1))
                    .cornerRadius(Theme.radiusSmall)
                }

                // Server Configuration
                VStack(alignment: .leading, spacing: 16) {
                    Text("Configuration")
                        .font(.headline)

                    HStack {
                        Text("Port:")
                        TextField("Port", text: $portString)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .disabled(apiService.isRunning)
                            .accessibilityLabel("Port number")
                            .accessibilityHint("Enter the port number for the API server")

                        Spacer()

                        Button("Restart Server") {
                            Task {
                                await restartServer()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!apiService.isRunning)
                        .accessibilityLabel("Restart server")
                    }
                }
                .padding()
                .background(Theme.surface)
                .cornerRadius(Theme.radiusSmall)

                Divider()

                // API Key
                VStack(alignment: .leading, spacing: 16) {
                    Text("API Authentication")
                        .font(.headline)

                    Text("Your API key authenticates all requests. Store it securely — it gives full access to your Chronicle data.")
                        .foregroundColor(Theme.textSecondary)

                    if let apiKey = currentAPIKey {
                        HStack {
                            if showAPIKey {
                                Text(apiKey)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .accessibilityLabel("API key: \(apiKey)")
                            } else {
                                Text(String(repeating: "•", count: apiKey.count))
                                    .font(.system(.caption, design: .monospaced))
                                    .accessibilityLabel("API key hidden")
                            }

                            Spacer()

                            Button(showAPIKey ? "Hide" : "Show") {
                                showAPIKey.toggle()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(showAPIKey ? "Hide API key" : "Show API key")

                            Button {
                                copyAPIKey(apiKey)
                            } label: {
                                Label(copiedKey ? "Copied!" : "Copy", systemImage: copiedKey ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .disabled(copiedKey)
                            .accessibilityLabel("Copy API key")

                            Button("Regenerate") {
                                regenerateKey()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(Theme.danger)
                            .accessibilityLabel("Regenerate API key")
                        }

                        Text("Regenerating will invalidate the previous key immediately.")
                            .font(.caption)
                            .foregroundColor(Theme.textTertiary)
                    } else {
                        Button("Generate API Key") {
                            currentAPIKey = APIKeyService.shared.generateKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Generate API key")
                    }
                }
                .padding()
                .background(Theme.surface)
                .cornerRadius(Theme.radiusSmall)

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

                    # Create a bill
                    curl -X POST -H "X-API-Key: \(currentAPIKey ?? "YOUR_KEY")" \\
                         -H "Content-Type: application/json" \\
                         -d '{"name":"Netflix","amountCents":1599,"dueDay":15,"dueDate":"2026-04-15T00:00:00Z","recurrence":"Monthly","category":"Subscriptions"}' \\
                         http://localhost:\(portString)/bills

                    # Get spending summary
                    curl -H "X-API-Key: \(currentAPIKey ?? "YOUR_KEY")" \\
                         http://localhost:\(portString)/summary

                    # Mark a bill as paid
                    curl -X PUT -H "X-API-Key: \(currentAPIKey ?? "YOUR_KEY")" \\
                         -H "Content-Type: application/json" \\
                         -d '{"isPaid":true}' \\
                         http://localhost:\(portString)/bills/BILL_ID

                    # OpenAPI documentation
                    http://localhost:\(portString)/openapi.json
                    """)
                }
            }
            .padding()
        }
        .frame(minWidth: 680, minHeight: 700)
        .onAppear {
            portString = String(apiService.port)
            currentAPIKey = APIKeyService.shared.storedKey
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
            endpointRow("GET", "/household", "Get household & balances")
            endpointRow("GET", "/health", "Health check (no auth)")
            endpointRow("GET", "/openapi.json", "OpenAPI 3.0 spec (no auth)")
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.radiusSmall)
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
                .foregroundColor(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(method) \(path): \(description)")
    }

    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return Theme.success
        case "POST": return Theme.accent
        case "PUT": return Theme.warning
        case "DELETE": return Theme.danger
        default: return Theme.textTertiary
        }
    }

    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(Theme.radiusSmall)
    }

    // MARK: - Actions

    private func startServer() async {
        do {
            if let port = UInt16(portString) {
                apiService.port = port
                try apiService.start()
            }
        } catch {
            print("Failed to start server: \(error)")
        }
    }

    private func stopServer() async {
        apiService.stop()
    }

    private func restartServer() async {
        do {
            if let port = UInt16(portString) {
                try apiService.restart(port: port)
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

    private func regenerateKey() {
        currentAPIKey = apiService.regenerateAPIKey()
    }

    private func openAPIDocs() {
        let urlString = "http://localhost:\(portString)/openapi.json"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
