import Foundation

/// Subscription tier for Chronicle
/// R16: Subscription Tiers & Monetization
public enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "free"
    case pro = "pro"
    case household = "household"
    case enterprise = "enterprise" // R17
    
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Chronicle Pro"
        case .household: return "Chronicle Household"
        case .enterprise: return "Chronicle Enterprise"
        }
    }
    
    public var monthlyPrice: Decimal? {
        switch self {
        case .free: return nil
        case .pro: return 2.99
        case .household: return 5.99
        case .enterprise: return nil // volume pricing
        }
    }
    
    public var yearlyPrice: Decimal? {
        switch self {
        case .free: return nil
        case .pro: return 19.99
        case .household: return 39.99
        case .enterprise: return nil
        }
    }
    
    public var maxBills: Int? {
        switch self {
        case .free: return 10
        case .pro: return nil // unlimited
        case .household: return nil
        case .enterprise: return nil
        }
    }
    
    public var maxHouseholdMembers: Int {
        switch self {
        case .free: return 1
        case .pro: return 1
        case .household: return 6
        case .enterprise: return Int.max
        }
    }
    
    public var supportsCustomRecurrence: Bool {
        self != .free
    }
    
    public var supportsMLReminders: Bool {
        self == .pro || self == .household || self == .enterprise
    }
    
    public var supportsTaxExport: Bool {
        self == .pro || self == .household || self == .enterprise
    }
    
    public var supportsBusinessTagging: Bool {
        self == .pro || self == .household || self == .enterprise
    }
    
    public var supportsAdvancedWidgets: Bool {
        self == .pro || self == .household || self == .enterprise
    }
    
    public var supportsShortcuts: Bool {
        self == .pro || self == .household || self == .enterprise
    }
    
    public var trialDays: Int {
        switch self {
        case .free: return 0
        case .pro, .household: return 14
        case .enterprise: return 30
        }
    }
}

/// Subscription status for the current user
public struct Subscription: Codable {
    public let tier: SubscriptionTier
    public let status: SubscriptionStatus
    public let expiresAt: Date?
    public let trialEndsAt: Date?
    public let gracePeriodEndsAt: Date?
    public let isFamilyShared: Bool
    public let transactionId: String?
    
    public init(
        tier: SubscriptionTier,
        status: SubscriptionStatus,
        expiresAt: Date? = nil,
        trialEndsAt: Date? = nil,
        gracePeriodEndsAt: Date? = nil,
        isFamilyShared: Bool = false,
        transactionId: String? = nil
    ) {
        self.tier = tier
        self.status = status
        self.expiresAt = expiresAt
        self.trialEndsAt = trialEndsAt
        self.gracePeriodEndsAt = gracePeriodEndsAt
        self.isFamilyShared = isFamilyShared
        self.transactionId = transactionId
    }
    
    public var isActive: Bool {
        status == .active || status == .inTrial || status == .inGracePeriod
    }
    
    public var canAccessProFeatures: Bool {
        tier != .free && isActive
    }
}

public enum SubscriptionStatus: String, Codable {
    case active
    case inTrial
    case inGracePeriod
    case expired
    case cancelled
}
