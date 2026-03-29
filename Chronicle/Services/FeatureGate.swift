import Foundation

/// R16: Feature gate enum and access logic
public enum Feature: String, CaseIterable {
    // MARK: - Pro Features
    case unlimitedBills
    case customRecurrence
    case smartReminders
    case spendingInsights
    case taxExport
    case businessTags
    case advancedWidgets
    case shortcutsIntegration
    
    // MARK: - Household Features
    case householdMembers
    case realTimeSync
    case splitBillTracking
    case settleUp
    case sharedInvoiceAttachments
    
    /// All features available to Pro tier (excludes household features).
    public static var proFeatures: [Feature] {
        [
            .unlimitedBills,
            .customRecurrence,
            .smartReminders,
            .spendingInsights,
            .taxExport,
            .businessTags,
            .advancedWidgets,
            .shortcutsIntegration,
        ]
    }
    
    /// All features available to Household tier (includes Pro + household features).
    public static var householdFeatures: [Feature] {
        proFeatures + [
            .householdMembers,
            .realTimeSync,
            .splitBillTracking,
            .settleUp,
            .sharedInvoiceAttachments,
        ]
    }
    
    /// Short user-facing description.
    public var description: String {
        switch self {
        case .unlimitedBills: return "Unlimited Bills"
        case .customRecurrence: return "Custom Recurrence"
        case .smartReminders: return "Smart Reminders"
        case .spendingInsights: return "Spending Insights"
        case .taxExport: return "Tax Export"
        case .businessTags: return "Business Tags"
        case .advancedWidgets: return "Advanced Widgets"
        case .shortcutsIntegration: return "Shortcuts Integration"
        case .householdMembers: return "Household Members"
        case .realTimeSync: return "Real-time Sync"
        case .splitBillTracking: return "Split Bill Tracking"
        case .settleUp: return "Settle Up"
        case .sharedInvoiceAttachments: return "Shared Invoice Attachments"
        }
    }
    
    /// SF Symbol icon name for the feature.
    public var iconName: String {
        switch self {
        case .unlimitedBills: return "infinity"
        case .customRecurrence: return "calendar.badge.clock"
        case .smartReminders: return "bell.badge"
        case .spendingInsights: return "chart.bar.xaxis"
        case .taxExport: return "doc.text"
        case .businessTags: return "tag"
        case .advancedWidgets: return "rectangle.3.group"
        case .shortcutsIntegration: return "gearshape.2"
        case .householdMembers: return "person.2"
        case .realTimeSync: return "arrow.triangle.2.circlepath"
        case .splitBillTracking: return "divide"
        case .settleUp: return "arrow.left.arrow.right"
        case .sharedInvoiceAttachments: return "paperclip"
        }
    }
    
    /// The minimum tier required to access this feature.
    public var requiredTier: SubscriptionTier {
        switch self {
        case .unlimitedBills,
             .customRecurrence,
             .smartReminders,
             .spendingInsights,
             .taxExport,
             .businessTags,
             .advancedWidgets,
             .shortcutsIntegration:
            return .pro
        case .householdMembers,
             .realTimeSync,
             .splitBillTracking,
             .settleUp,
             .sharedInvoiceAttachments:
            return .household
        default:
            // Future-proof: treat unknown household features as requiring household
            return .household
        }
    }
}

/// Shared feature gate logic - separate from SubscriptionService to allow
/// lightweight feature checks without async StoreKit calls.
public final class FeatureGate {
    
    public static let shared = FeatureGate()
    
    private init() {}
    
    /// Returns true if the given feature is unlocked for the specified tier.
    public func isUnlocked(_ feature: Feature, for tier: SubscriptionTier) -> Bool {
        switch tier {
        case .free:
            // Free: only basic recurrence (non-custom), menu bar access
            return !feature.requiresProOrHigher
        case .pro:
            // Pro: all pro features, no household features
            return !feature.requiresHousehold
        case .household, .enterprise:
            // Household/Enterprise: all features
            return true
        }
    }
    
    /// Returns the lock reason message if the feature is not unlocked, nil otherwise.
    public func lockReason(for feature: Feature, currentTier: SubscriptionTier) -> String? {
        if isUnlocked(feature, for: currentTier) { return nil }
        
        switch feature.requiredTier {
        case .pro:
            return "Upgrade to Pro to unlock \(feature.description)"
        case .household:
            return "Upgrade to Household to unlock \(feature.description)"
        case .free:
            return nil
        case .enterprise:
            return "Enterprise feature"
        }
    }
}

// MARK: - Feature Extension

fileprivate extension Feature {
    /// True if this feature requires Pro or higher (not available on Free).
    var requiresProOrHigher: Bool {
        requiredTier == .pro || requiredTier == .household
    }
    
    /// True if this feature requires Household tier.
    var requiresHousehold: Bool {
        requiredTier == .household
    }
}
