import Foundation

/// R17: MDM / Managed Apple ID Support
/// Detects and applies managed configuration policies
final class MDMService: ObservableObject {
    
    static let shared = MDMService()
    
    @Published private(set) var isManagedDevice: Bool = false
    @Published private(set) var mdmConfig: MDMConfig?
    @Published private(set) var organizationName: String?
    
    private let managedConfigKey = "com.apple.configuration.managed"
    
    private init() {
        checkManagedStatus()
    }
    
    // MARK: - Detection
    
    /// Checks if the device is managed via MDM
    func checkManagedStatus() {
        // On macOS, we check for managed configuration via SystemConfiguration
        // This would use SCManagedConfiguration on a real MDM-enrolled device
        
        // For now, check UserDefaults for managed config (set by MDM profile)
        if let managedConfig = UserDefaults.standard.dictionary(forKey: managedConfigKey) {
            isManagedDevice = true
            mdmConfig = parseManagedConfig(managedConfig)
            organizationName = managedConfig["organizationName"] as? String
        } else {
            isManagedDevice = false
            mdmConfig = nil
            organizationName = nil
        }
    }
    
    private func parseManagedConfig(_ config: [String: Any]) -> MDMConfig {
        var mdmConfig = MDMConfig()
        
        // Parse team policy
        if let policyDict = config["teamPolicy"] as? [String: Any] {
            mdmConfig.teamPolicy = TeamPolicy(
                requireCategory: policyDict["requireCategory"] as? Bool ?? false,
                blockPersonalBills: policyDict["blockPersonalBills"] as? Bool ?? false,
                defaultReminderDays: policyDict["defaultReminderDays"] as? Int ?? 3,
                allowedCategories: nil
            )
        }
        
        // Parse allowed categories
        if let categories = config["allowedCategories"] as? [String] {
            mdmConfig.allowedCategories = categories.compactMap { Category(rawValue: $0) }
        }
        
        // Parse force sync setting
        mdmConfig.forceSyncToTeam = config["forceSyncToTeam"] as? Bool ?? false
        
        return mdmConfig
    }
    
    // MARK: - Policy Application
    
    /// Returns effective team policy (MDM policy takes precedence over user settings)
    func effectiveTeamPolicy(userPolicy: TeamPolicy?) -> TeamPolicy {
        guard isManagedDevice, let mdmPolicy = mdmConfig?.teamPolicy else {
            return userPolicy ?? TeamPolicy()
        }
        
        // MDM policy takes precedence
        return mdmPolicy
    }
    
    /// Returns effective allowed categories
    func effectiveAllowedCategories() -> [Category]? {
        if isManagedDevice, let categories = mdmConfig?.allowedCategories {
            return categories
        }
        return nil
    }
    
    /// Checks if personal bills are blocked by policy
    func personalBillsBlocked() -> Bool {
        return mdmConfig?.teamPolicy?.blockPersonalBills ?? false
    }
    
    // MARK: - Validation
    
    /// Validates if a bill meets MDM requirements
    func validateBillForMDMPolicy(_ bill: Bill) -> (valid: Bool, reason: String?) {
        guard isManagedDevice else { return (true, nil) }
        
        // Check category requirement
        if mdmConfig?.teamPolicy?.requireCategory == true {
            if bill.category == .other {
                return (false, "Category is required by organization policy")
            }
        }
        
        // Check allowed categories
        if let allowed = mdmConfig?.allowedCategories, !allowed.isEmpty {
            if !allowed.contains(bill.category) {
                return (false, "Category '\(bill.category.rawValue)' is not allowed by organization policy")
            }
        }
        
        return (true, nil)
    }
}

// MARK: - MDM Configuration

struct MDMConfig: Codable {
    var isManagedDevice: Bool { MDMService.shared.isManagedDevice }
    var teamPolicy: TeamPolicy?
    var allowedCategories: [Category]?
    var forceSyncToTeam: Bool = false
    
    init(
        teamPolicy: TeamPolicy? = nil,
        allowedCategories: [Category]? = nil,
        forceSyncToTeam: Bool = false
    ) {
        self.teamPolicy = teamPolicy
        self.allowedCategories = allowedCategories
        self.forceSyncToTeam = forceSyncToTeam
    }
}
