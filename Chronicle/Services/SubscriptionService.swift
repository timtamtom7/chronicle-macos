import Foundation
import Combine
// Note: StoreKit NOT imported here because StoreKit.SubscriptionStatus would conflict
// with our local ChronicleSubscriptionStatus struct. StoreKit types accessed via StoreKitService.

/// R16: Subscription status struct
public struct ChronicleSubscriptionStatus: Codable {
    var tier: SubscriptionTier = .free
    var isTrialActive: Bool = false
    var trialExpiresAt: Date?
    var subscriptionExpiresAt: Date?
    var isGracePeriodActive: Bool = false
}

/// R16: High-level subscription service wrapping StoreKit + local status
/// Coordinates between FeatureGate, StoreKitService, and UserDefaults persistence
@available(macOS 13.0, *)
public final class SubscriptionService: ObservableObject {
    
    public static let shared = SubscriptionService()
    
    // MARK: - Published State
    
    @Published public private(set) var status: ChronicleSubscriptionStatus
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let tier = "ChronicleSubscriptionTier"
        static let trialExpiresAt = "ChronicleTrialExpiresAt"
        static let subscriptionExpiresAt = "ChronicleSubscriptionExpiresAt"
        static let isGracePeriodActive = "ChronicleGracePeriodActive"
        static let gracePeriodExpiresAt = "ChronicleGracePeriodExpiresAt"
        static let hasStartedTrial = "ChronicleHasStartedTrial"
        static let billCountAtLastCheck = "ChronicleBillCountAtLastCheck"
    }
    
    private let defaults: UserDefaults
    private let featureGate: FeatureGate
    private let storeKit: StoreKitService
    
    // MARK: - Init
    
    private init(
        defaults: UserDefaults = .standard,
        featureGate: FeatureGate = .shared,
        storeKit: StoreKitService = .shared
    ) {
        self.defaults = defaults
        self.featureGate = featureGate
        self.storeKit = storeKit
        self.status = Self.loadStatus(from: defaults)
        
        // Sync StoreKit status on launch
        Task {
            await refreshStatus()
        }
    }
    
    // MARK: - Public API
    
    /// Returns the current subscription status from local cache.
    public func getStatus() -> ChronicleSubscriptionStatus {
        status
    }
    
    /// Refreshes status from StoreKit and merges with local cache.
    public func refreshStatus() async {
        await MainActor.run { isLoading = true }
        
        // Get StoreKit entitlements
        let storeKitTier = await storeKit.checkSubscriptionStatus()
        
        // Merge: StoreKit wins if it shows active, otherwise use local
        var updated = status
        
        if let storeTier = storeKitTier {
            updated.tier = storeTier
            updated.subscriptionExpiresAt = storeKit.subscriptionExpiresAt
            updated.isTrialActive = false
            updated.isGracePeriodActive = false
        } else {
            // Check if local trial/grace period is still valid
            updated = Self.validateStatus(updated)
        }
        
        await MainActor.run {
            self.status = updated
            self.isLoading = false
        }
        
        persistStatus(updated)
    }
    
    /// Initiates a purchase for the given tier (resolves to monthly or yearly product).
    public func upgrade(to tier: SubscriptionTier) async throws {
        guard tier != .free else { return }
        
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            let product = try await storeKit.product(for: tier)
            let transaction = try await storeKit.purchase(product: product)
            
            if transaction != nil {
                await refreshStatus()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    /// Restores purchases from StoreKit.
    public func restorePurchases() async throws {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        try await storeKit.restorePurchases()
        await refreshStatus()
    }
    
    /// Checks if the given feature is accessible for the current tier.
    public func isFeatureUnlocked(_ feature: Feature) -> Bool {
        featureGate.isUnlocked(feature, for: status.tier)
    }
    
    /// Starts a 14-day trial for Pro or Household if the user is eligible.
    public func startTrial(ifEligible: Bool) async -> Bool {
        guard ifEligible else { return false }
        guard status.tier != .free else { return false }
        guard !defaults.bool(forKey: Keys.hasStartedTrial) else { return false }
        
        let tier: SubscriptionTier
        switch status.tier {
        case .pro, .household:
            tier = status.tier
        default:
            tier = .pro
        }
        
        let trialEnds = Calendar.current.date(byAdding: .day, value: 14, to: Date())
        
        var updated = status
        updated.tier = tier
        updated.isTrialActive = true
        updated.trialExpiresAt = trialEnds
        
        defaults.set(true, forKey: Keys.hasStartedTrial)
        
        await MainActor.run {
            self.status = updated
        }
        persistStatus(updated)
        
        return true
    }
    
    /// Checks and activates 3-day grace period if payment recently failed.
    public func checkGracePeriod() {
        var updated = status
        
        if updated.isGracePeriodActive {
            if let expiresAt = updated.trialExpiresAt, Date() > expiresAt {
                updated.isGracePeriodActive = false
            }
        }
        
        status = updated
        persistStatus(updated)
    }
    
    /// Shows the upgrade prompt when free user is near their bill limit.
    public func shouldShowUpgradeNudge() -> Bool {
        guard status.tier == .free else { return false }
        
        let billCount = defaults.integer(forKey: Keys.billCountAtLastCheck)
        return billCount >= 10
    }
    
    /// Records the current bill count for upgrade nudge logic.
    public func recordBillCount(_ count: Int) {
        defaults.set(count, forKey: Keys.billCountAtLastCheck)
    }
    
    // MARK: - Private Helpers
    
    private static func loadStatus(from defaults: UserDefaults) -> ChronicleSubscriptionStatus {
        var status = ChronicleSubscriptionStatus()
        if let tierRaw = defaults.string(forKey: Keys.tier),
           let tier = SubscriptionTier(rawValue: tierRaw) {
            status.tier = tier
        }
        status.trialExpiresAt = defaults.object(forKey: Keys.trialExpiresAt) as? Date
        status.subscriptionExpiresAt = defaults.object(forKey: Keys.subscriptionExpiresAt) as? Date
        status.isGracePeriodActive = defaults.bool(forKey: Keys.isGracePeriodActive)
        
        // Check if grace period expired
        if status.isGracePeriodActive,
           let graceExpiry = defaults.object(forKey: Keys.gracePeriodExpiresAt) as? Date,
           Date() > graceExpiry {
            status.isGracePeriodActive = false
        }
        
        // Check if trial expired
        if status.isTrialActive,
           let trialExpiry = status.trialExpiresAt,
           Date() > trialExpiry {
            status.isTrialActive = false
        }
        
        return status
    }
    
    private func persistStatus(_ status: ChronicleSubscriptionStatus) {
        defaults.set(status.tier.rawValue, forKey: Keys.tier)
        defaults.set(status.trialExpiresAt, forKey: Keys.trialExpiresAt)
        defaults.set(status.subscriptionExpiresAt, forKey: Keys.subscriptionExpiresAt)
        defaults.set(status.isGracePeriodActive, forKey: Keys.isGracePeriodActive)
        if status.isGracePeriodActive,
           let graceExpiry = Calendar.current.date(byAdding: .day, value: 3, to: Date()) {
            defaults.set(graceExpiry, forKey: Keys.gracePeriodExpiresAt)
        }
    }
    
    private static func validateStatus(_ status: ChronicleSubscriptionStatus) -> ChronicleSubscriptionStatus {
        var updated = status
        
        if updated.isTrialActive, let trialExpiry = updated.trialExpiresAt, Date() > trialExpiry {
            updated.isTrialActive = false
        }
        
        if updated.isGracePeriodActive, let graceExpiry = updated.trialExpiresAt, Date() > graceExpiry {
            updated.isGracePeriodActive = false
        }
        
        return updated
    }
}
