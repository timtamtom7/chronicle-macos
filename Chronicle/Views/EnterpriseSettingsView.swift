import SwiftUI

/// R17: Enterprise Settings View
/// SSO/SAML configuration and enterprise features
struct EnterpriseSettingsView: View {
    @StateObject private var teamService = TeamService.shared
    @StateObject private var mdmService = MDMService.shared
    @StateObject private var dataResidencyService = DataResidencyService.shared
    
    @State private var showSSOAlert = false
    @State private var selectedIdP: IdentityProvider = .okta
    @State private var idpURL: String = ""
    @State private var entityID: String = ""
    @State private var acsURL: String = ""
    
    private var isEnterpriseAccount: Bool {
        // In production, check subscription tier from auth service
        return true
    }
    
    var body: some View {
        Form {
            // MARK: - MDM Status Badge
            if mdmService.isManagedDevice {
                Section {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Managed by \(mdmService.organizationName ?? "Your Organization")")
                                .font(.headline)
                            Text("Some settings are controlled by your organization")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // MARK: - SSO Section (Enterprise only)
            if isEnterpriseAccount {
                Section {
                    Text("Single Sign-On (SSO)")
                        .font(.headline)
                    
                    Button(action: { showSSOAlert = true }) {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                            Text("Sign in with SSO")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .alert("SSO Configuration", isPresented: $showSSOAlert) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("SSO is configured. This would open your identity provider for authentication.")
                    }
                } header: {
                    Text("Enterprise Authentication")
                }
                
                // MARK: - Identity Provider Configuration
                Section {
                    Text("Configure Identity Provider")
                        .font(.subheadline)
                    
                    // Supported IdPs
                    Picker("Identity Provider", selection: $selectedIdP) {
                        ForEach(IdentityProvider.allCases, id: \.self) { idp in
                            Text(idp.displayName).tag(idp)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("IdP URL", text: $idpURL)
                        .textFieldStyle(.roundedBorder)
                        .placeholder(when: idpURL.isEmpty) {
                            Text("https://your-org.okta.com")
                                .foregroundColor(.secondary)
                        }
                    
                    TextField("Entity ID", text: $entityID)
                        .textFieldStyle(.roundedBorder)
                        .placeholder(when: entityID.isEmpty) {
                            Text("Your application entity ID")
                                .foregroundColor(.secondary)
                        }
                    
                    TextField("ACS URL", text: $acsURL)
                        .textFieldStyle(.roundedBorder)
                        .placeholder(when: acsURL.isEmpty) {
                            Text("Assertion Consumer Service URL")
                                .foregroundColor(.secondary)
                        }
                    
                    Button("Save SSO Configuration") {
                        saveSSOConfiguration()
                    }
                    .disabled(idpURL.isEmpty || entityID.isEmpty || acsURL.isEmpty)
                } header: {
                    Text("SAML 2.0 Configuration")
                } footer: {
                    Text("Contact your IT administrator for the correct IdP settings.")
                }
            }
            
            // MARK: - Data Residency Section
            Section {
                Text("Data Residency")
                    .font(.headline)
                
                HStack {
                    Text("Storage Region")
                    Spacer()
                    Text("\(dataResidencyService.currentRegion.flag) \(dataResidencyService.currentRegion.displayName)")
                        .foregroundColor(.secondary)
                }
                
                Text(dataResidencyService.regionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if dataResidencyService.isLocked {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                        Text("Region cannot be changed after initial setup")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Picker("Select Region", selection: Binding(
                        get: { dataResidencyService.currentRegion },
                        set: { _ in } // Read-only display in settings
                    )) {
                        ForEach(DataRegion.allCases, id: \.self) { region in
                            Text("\(region.flag) \(region.displayName)").tag(region)
                        }
                    }
                }
            } header: {
                Text("Data Storage")
            }
            
            // MARK: - Audit Log Section
            Section {
                NavigationLink {
                    AuditLogView()
                } label: {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View Audit Log")
                    }
                }
                
                Button(action: exportAuditLog) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Audit Log (CSV)")
                    }
                }
            } header: {
                Text("Compliance")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadSSOConfiguration()
        }
    }
    
    // MARK: - Actions
    
    private func saveSSOConfiguration() {
        let config = SSOConfiguration(
            idpType: selectedIdP,
            ssoURL: idpURL,
            entityID: entityID,
            acsURL: acsURL
        )
        
        // Save to UserDefaults or MDM config
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "chronicle_sso_config")
        }
    }
    
    private func loadSSOConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: "chronicle_sso_config"),
              let config = try? JSONDecoder().decode(SSOConfiguration.self, from: data) else {
            return
        }
        
        selectedIdP = config.idpType
        idpURL = config.ssoURL ?? ""
        entityID = config.entityID ?? ""
        acsURL = config.acsURL ?? ""
    }
    
    private func exportAuditLog() {
        guard let url = AuditLogService.shared.exportToCSV(entries: AuditLogService.shared.entries) else {
            return
        }
        
        // macOS: Use NSWorkspace to reveal in Finder
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}

// MARK: - Audit Log View

struct AuditLogView: View {
    @StateObject private var auditService = AuditLogService.shared
    
    @State private var filterActorId: UUID?
    @State private var filterStartDate: Date?
    @State private var filterEndDate: Date?
    @State private var selectedAction: AuditAction?
    
    private var filteredEntries: [AuditLogEntry] {
        var result = auditService.entries
        
        if let actorId = filterActorId {
            result = result.filter { $0.actorId == actorId }
        }
        
        if let start = filterStartDate, let end = filterEndDate {
            result = result.filter { $0.timestamp >= start && $0.timestamp <= end }
        }
        
        if let action = selectedAction {
            result = result.filter { $0.action == action }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filters
            HStack {
                Picker("Action", selection: $selectedAction) {
                    Text("All Actions").tag(nil as AuditAction?)
                    ForEach(AuditAction.allCases, id: \.self) { action in
                        Text(action.rawValue).tag(action as AuditAction?)
                    }
                }
                .frame(width: 200)
                
                Spacer()
                
                Button("Export") {
                    _ = AuditLogService.shared.exportToCSV(entries: filteredEntries)
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            // Log entries
            List(filteredEntries, id: \.id) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.action.rawValue)
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(entry.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.secondary)
                        Text(entry.actorName)
                            .font(.subheadline)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(entry.entityType)/\(entry.entityId.uuidString.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let details = entry.details, !details.isEmpty {
                        Text(details.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
        }
        .navigationTitle("Audit Log")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: refreshLog) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
    
    private func refreshLog() {
        // Reload entries
    }
}

// MARK: - SSO Configuration

struct SSOConfiguration: Codable {
    var idpType: IdentityProvider
    var ssoURL: String?
    var entityID: String?
    var acsURL: String?
    var metadataURL: String?
    
    init(
        idpType: IdentityProvider = .okta,
        ssoURL: String? = nil,
        entityID: String? = nil,
        acsURL: String? = nil,
        metadataURL: String? = nil
    ) {
        self.idpType = idpType
        self.ssoURL = ssoURL
        self.entityID = entityID
        self.acsURL = acsURL
        self.metadataURL = metadataURL
    }
}

// MARK: - Identity Provider

enum IdentityProvider: String, Codable, CaseIterable {
    case okta = "Okta"
    case azureAD = "Azure AD"
    case googleWorkspace = "Google Workspace"
    
    var displayName: String { rawValue }
}

// MARK: - Placeholder Modifier

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - AuditAction CaseIterable

extension AuditAction: CaseIterable {
    static var allCases: [AuditAction] {
        [.billCreated, .billUpdated, .billDeleted, .billPaid, .billUnpaid,
         .memberInvited, .memberJoined, .memberRemoved, .memberRoleChanged,
         .policyUpdated, .teamCreated]
    }
}
