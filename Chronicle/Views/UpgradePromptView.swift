import SwiftUI

/// R16: Upgrade prompt modal sheet shown to free users hitting limits or accessing pro features.
struct UpgradePromptView: View {
    @Binding var isPresented: Bool
    
    /// What triggered the prompt - affects headline messaging.
    var trigger: UpgradeTrigger = .billLimit
    
    @State private var selectedTier: SubscriptionTier = .pro
    @State private var isLoading = false
    @State private var errorMessage: String?
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var storeKit = StoreKitService.shared
    
    public enum UpgradeTrigger {
        case billLimit       // Free user at 10 bills
        case proFeature       // User tried a Pro feature
        case householdFeature // User tried a Household feature
        case settings         // Explicitly from Settings
        
        var headline: String {
            switch self {
            case .billLimit: return "You've reached your free limit"
            case .proFeature: return "Unlock Pro Features"
            case .householdFeature: return "Unlock Household Features"
            case .settings: return "Upgrade Chronicle"
            }
        }
        
        var subheadline: String {
            switch self {
            case .billLimit:
                return "You've added 10 bills. Upgrade to Pro for unlimited bills and more."
            case .proFeature:
                return "This feature requires Chronicle Pro or Household."
            case .householdFeature:
                return "This feature requires Chronicle Household."
            case .settings:
                return "Choose the plan that works best for you."
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            ScrollView {
                VStack(spacing: Theme.spacing16) {
                    // Trigger message
                    triggerMessage
                    
                    // Tier comparison
                    tierComparisonTable
                    
                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Theme.danger)
                            .padding(.horizontal, Theme.spacing12)
                    }
                }
                .padding(Theme.spacing16)
            }
            
            Divider()
            
            // Footer
            footer
        }
        .frame(width: 520, height: 580)
        .background(Theme.background)
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Upgrade Chronicle")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Text(trigger.subheadline)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.footnote)
                    .foregroundColor(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.spacing16)
    }
    
    private var triggerMessage: some View {
        VStack(spacing: Theme.spacing8) {
            Image(systemName: trigger == .billLimit ? "lock.fill" : "star.fill")
                .font(.system(size: 32))
                .foregroundColor(Theme.accent)
            
            Text(trigger.headline)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacing8)
    }
    
    private var tierComparisonTable: some View {
        VStack(spacing: Theme.spacing8) {
            // Column headers
            HStack(spacing: Theme.spacing8) {
                Spacer()
                    .frame(width: 100)
                
                tierColumnHeader(tier: .free, selected: selectedTier == .free) {
                    selectedTier = .free
                }
                
                tierColumnHeader(tier: .pro, selected: selectedTier == .pro) {
                    selectedTier = .pro
                }
                
                tierColumnHeader(tier: .household, selected: selectedTier == .household) {
                    selectedTier = .household
                }
            }
            .padding(.horizontal, Theme.spacing4)
            
            Divider()
            
            // Feature rows
            ForEach(Feature.allCases, id: \.self) { feature in
                featureRow(feature)
            }
        }
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }
    
    private func tierColumnHeader(tier: SubscriptionTier, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(tier.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(selected ? Theme.accent : Theme.textSecondary)
                
                if tier == .pro {
                    Text("$2.99/mo")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                } else if tier == .household {
                    Text("$5.99/mo")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                } else {
                    Text("Free")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
                
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(Theme.accent)
                }
            }
            .frame(width: 90)
            .padding(.vertical, Theme.spacing8)
            .background(selected ? Theme.accent.opacity(0.1) : Color.clear)
            .cornerRadius(Theme.radiusSmall)
        }
        .buttonStyle(.plain)
    }
    
    private func featureRow(_ feature: Feature) -> some View {
        HStack(spacing: Theme.spacing8) {
            // Feature name
            HStack(spacing: 4) {
                Image(systemName: feature.iconName)
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
                    .frame(width: 14)
                Text(feature.description)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            // Free tier
            tierFeatureAccessCell(feature, tier: .free)
            
            // Pro tier
            tierFeatureAccessCell(feature, tier: .pro)
            
            // Household tier
            tierFeatureAccessCell(feature, tier: .household)
        }
        .padding(.horizontal, Theme.spacing4)
        .padding(.vertical, 6)
    }
    
    private func tierFeatureAccessCell(_ feature: Feature, tier: SubscriptionTier) -> some View {
        let gate = FeatureGate.shared
        let unlocked = gate.isUnlocked(feature, for: tier)
        
        return ZStack {
            if unlocked {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.success)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary.opacity(0.5))
            }
        }
        .frame(width: 90)
    }
    
    private var footer: some View {
        HStack {
            // Restore
            Button("Restore Purchases") {
                Task {
                    try? await subscriptionService.restorePurchases()
                }
            }
            .font(.footnote)
            .foregroundColor(Theme.textSecondary)
            .accessibilityLabel("Restore purchases")
            
            Spacer()
            
            if subscriptionService.status.tier == .free {
                // Free trial option
                if let trialEndsAt = subscriptionService.status.trialExpiresAt,
                   Date() < trialEndsAt {
                    Text("Trial active until \(trialEndsAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(Theme.success)
                } else {
                    Button("Start Free Trial") {
                        Task {
                            _ = await subscriptionService.startTrial(ifEligible: true)
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(Theme.accent)
                    .accessibilityLabel("Start free trial")
                }
            }
            
            Button {
                Task {
                    isLoading = true
                    errorMessage = nil
                    do {
                        try await subscriptionService.upgrade(to: selectedTier)
                        await MainActor.run {
                            isLoading = false
                            isPresented = false
                        }
                    } catch {
                        await MainActor.run {
                            self.errorMessage = error.localizedDescription
                            isLoading = false
                        }
                    }
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 80)
                } else {
                    Text(selectedTier == .free ? "Close" : "Upgrade")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textOnAccent)
                        .frame(width: 80)
                        .padding(.vertical, 6)
                        .background(Theme.accent)
                        .cornerRadius(Theme.radiusSmall)
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .accessibilityLabel("Upgrade to \(selectedTier.displayName)")
        }
        .padding(Theme.spacing16)
    }
}

// MARK: - Lock Icon Modifier

/// Adds a lock badge to any view for locked features.
struct FeatureLockBadge: View {
    let feature: Feature
    let currentTier: SubscriptionTier
    
    @State private var showTooltip = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .frame(width: 0, height: 0)
            
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
                .padding(2)
                .background(Theme.surface.opacity(0.9))
                .cornerRadius(4)
                .onHover { hovering in
                    showTooltip = hovering
                }
                .popover(isPresented: $showTooltip) {
                    Text(lockReason)
                        .font(.caption)
                        .padding(8)
                }
        }
    }
    
    private var lockReason: String {
        FeatureGate.shared.lockReason(for: feature, currentTier: currentTier) ?? ""
    }
}
