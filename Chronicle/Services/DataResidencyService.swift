import Foundation

/// R17: Data Residency Configuration
/// Manages user preference for data storage region
final class DataResidencyService: ObservableObject {
    
    static let shared = DataResidencyService()
    
    @Published private(set) var currentRegion: DataRegion
    @Published private(set) var isLocked: Bool
    
    private let userDefaultsKey = "chronicle_data_region"
    private let setupCompletedKey = "chronicle_data_region_setup_completed"
    
    private init() {
        // Load saved region or default to US
        if let savedRegion = UserDefaults.standard.string(forKey: userDefaultsKey),
           let region = DataRegion(rawValue: savedRegion) {
            self.currentRegion = region
        } else {
            self.currentRegion = .us
        }
        
        // Check if setup has been completed (locked after initial setup)
        self.isLocked = UserDefaults.standard.bool(forKey: setupCompletedKey)
    }
    
    // MARK: - Region Selection
    
    /// Sets the data region preference (only allowed before setup is completed)
    func setRegion(_ region: DataRegion) -> Bool {
        if isLocked {
            return false
        }
        
        currentRegion = region
        UserDefaults.standard.set(region.rawValue, forKey: userDefaultsKey)
        return true
    }
    
    /// Marks setup as complete, locking the region choice
    func completeSetup() {
        isLocked = true
        UserDefaults.standard.set(true, forKey: setupCompletedKey)
    }
    
    /// Returns the display name for the current region
    var regionDisplayName: String {
        currentRegion.displayName
    }
    
    /// Returns a description of data practices for the current region
    var regionDescription: String {
        switch currentRegion {
        case .us:
            return "Your data is stored on servers in the United States"
        case .eu:
            return "Your data is stored on servers in the European Union in compliance with GDPR"
        case .apac:
            return "Your data is stored on servers in Asia Pacific region"
        }
    }
    
    /// Resets the region (for testing/admin purposes only)
    func resetRegion() {
        currentRegion = .us
        isLocked = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: setupCompletedKey)
    }
}

// MARK: - Data Region

enum DataRegion: String, CaseIterable, Codable {
    case us = "United States"
    case eu = "European Union"
    case apac = "Asia Pacific"
    
    var displayName: String { rawValue }
    
    var flag: String {
        switch self {
        case .us: return "🇺🇸"
        case .eu: return "🇪🇺"
        case .apac: return "🌏"
        }
    }
    
    var code: String {
        switch self {
        case .us: return "US"
        case .eu: return "EU"
        case .apac: return "APAC"
        }
    }
}
