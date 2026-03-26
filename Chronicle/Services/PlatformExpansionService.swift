import Foundation

/// R20: Platform Expansion Services
/// Android companion, Vision Pro, open-source core, integration ecosystem

// MARK: - Integration Registry

public struct Integration: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var category: IntegrationCategory
    public var description: String
    public var iconName: String
    public var isEnabled: Bool
    public var apiKey: String?
    public var lastSyncAt: Date?
    
    public init(
        id: UUID = UUID(),
        name: String,
        category: IntegrationCategory,
        description: String,
        iconName: String,
        isEnabled: Bool = false,
        apiKey: String? = nil,
        lastSyncAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.iconName = iconName
        self.isEnabled = isEnabled
        self.apiKey = apiKey
        self.lastSyncAt = lastSyncAt
    }
}

public enum IntegrationCategory: String, Codable, CaseIterable {
    case budgeting = "Budgeting"
    case accounting = "Accounting"
    case banking = "Banking"
    case automation = "Automation"
    case export = "Export"
    case other = "Other"
}

/// R20: Integration ecosystem service
public final class IntegrationRegistry: ObservableObject {
    
    public static let shared = IntegrationRegistry()
    
    @Published public private(set) var integrations: [Integration] = []
    @Published public private(set) var availableIntegrations: [Integration] = []
    
    private let storageKey = "chronicle_integrations"
    
    private init() {
        setupAvailableIntegrations()
        loadIntegrations()
    }
    
    private func setupAvailableIntegrations() {
        availableIntegrations = [
            Integration(name: "YNAB", category: .budgeting, description: "Sync bills with You Need A Budget", iconName: "dollarsign.circle"),
            Integration(name: "Mint", category: .budgeting, description: "Import data from Mint", iconName: "leaf"),
            Integration(name: "Personal Capital", category: .banking, description: "Track spending with Personal Capital", iconName: "building.columns"),
            Integration(name: "Copilot", category: .banking, description: "Copilot Money integration", iconName: "creditcard"),
            Integration(name: "IFTTT", category: .automation, description: "IFTTT automation triggers", iconName: "bolt"),
            Integration(name: "Zapier", category: .automation, description: "Zapier workflow automation", iconName: "arrow.triangle.2.circlepath"),
            Integration(name: "Make", category: .automation, description: "Make (Integromat) scenarios", iconName: "gearshape.2"),
            Integration(name: "QuickBooks", category: .accounting, description: "Export to QuickBooks", iconName: "doc.text"),
            Integration(name: "FreshBooks", category: .accounting, description: "FreshBooks accounting sync", iconName: "doc.text"),
        ]
    }
    
    public func enableIntegration(_ id: UUID, apiKey: String?) throws {
        guard var integration = integrations.first(where: { $0.id == id }) else {
            throw IntegrationError.notFound
        }
        
        integration.isEnabled = true
        integration.apiKey = apiKey
        
        if let index = integrations.firstIndex(where: { $0.id == id }) {
            integrations[index] = integration
        } else {
            integrations.append(integration)
        }
        
        saveIntegrations()
    }
    
    public func disableIntegration(_ id: UUID) {
        guard let index = integrations.firstIndex(where: { $0.id == id }) else { return }
        integrations[index].isEnabled = false
        integrations[index].apiKey = nil
        saveIntegrations()
    }
    
    public func syncIntegration(_ id: UUID) async throws {
        // R20: Implement actual sync logic
        guard let index = integrations.firstIndex(where: { $0.id == id }) else {
            throw IntegrationError.notFound
        }
        
        integrations[index].lastSyncAt = Date()
        saveIntegrations()
    }
    
    private func loadIntegrations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Integration].self, from: data) else {
            return
        }
        integrations = decoded
    }
    
    private func saveIntegrations() {
        guard let data = try? JSONEncoder().encode(integrations) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

public enum IntegrationError: Error, LocalizedError {
    case notFound
    case syncFailed
    case authenticationFailed
    
    public var errorDescription: String? {
        switch self {
        case .notFound: return "Integration not found"
        case .syncFailed: return "Sync failed"
        case .authenticationFailed: return "Authentication failed"
        }
    }
}

// MARK: - Vision Pro Service (R20)

/// R20: Vision Pro spatial computing service
@available(visionOS 1.0, macOS 14.0, *)
public final class VisionProService: ObservableObject {
    
    public static let shared = VisionProService()
    
    @Published public var spatialWindowPosition: SIMD3<Float> = .zero
    @Published public var spatialWindowScale: Float = 1.0
    
    private init() {}
    
    /// Opens the bills overview in a spatial window arrangement
    public func openBillsOverview() {
        // R20: Implement spatial window positioning for visionOS
        // Would use RealityKit or SwiftUI spatial containers
    }
    
    /// Shows the spending chart as a 3D visualization
    public func show3DSpendingChart() {
        // R20: Implement 3D chart visualization for Vision Pro
    }
    
    /// Creates an immersive overview of all bills
    public func createImmersiveOverview() {
        // R20: Implement immersive spatial experience
    }
}

// MARK: - Open Source Core (R20)

/// R20: Open source core engine information
public struct OpenSourceCoreInfo {
    public static let repositoryURL = "https://github.com/chronicle-app/chronicle-core"
    public static let license = "MIT"
    public static let version = "1.0.0"
    
    public static var isCommunityContributionEnabled: Bool { true }
}
