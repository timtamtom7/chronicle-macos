import Foundation
import StoreKit

/// R16: Subscription management with StoreKit 2
/// Handles subscription tiers, trials, grace periods, and entitlement checks
@available(macOS 13.0, *)
public final class SubscriptionManager: ObservableObject {
    
    public static let shared = SubscriptionManager()
    
    @Published public private(set) var currentSubscription: Subscription?
    @Published public private(set) var isLoading = false
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var errorMessage: String?
    
    // Product IDs
    private let proMonthlyID = "com.chronicle.macos.pro.monthly"
    private let proYearlyID = "com.chronicle.macos.pro.yearly"
    private let householdMonthlyID = "com.chronicle.macos.household.monthly"
    private let householdYearlyID = "com.chronicle.macos.household.yearly"
    
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Products
    
    public func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIDs = [proMonthlyID, proYearlyID, householdMonthlyID, householdYearlyID]
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    
    public func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return transaction
            
        case .userCancelled:
            return nil
            
        case .pending:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    // MARK: - Subscription Status
    
    public func updateSubscriptionStatus() async {
        var finalSubscription: Subscription = Subscription(tier: .free, status: .active)
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID == proMonthlyID || transaction.productID == proYearlyID {
                    finalSubscription = Subscription(
                        tier: .pro,
                        status: transaction.revocationDate == nil ? .active : .expired,
                        expiresAt: transaction.expirationDate,
                        trialEndsAt: transaction.offerType == .introductory ? transaction.expirationDate : nil,
                        transactionId: String(transaction.id)
                    )
                } else if transaction.productID == householdMonthlyID || transaction.productID == householdYearlyID {
                    finalSubscription = Subscription(
                        tier: .household,
                        status: transaction.revocationDate == nil ? .active : .expired,
                        expiresAt: transaction.expirationDate,
                        trialEndsAt: transaction.offerType == .introductory ? transaction.expirationDate : nil,
                        isFamilyShared: true,
                        transactionId: String(transaction.id)
                    )
                }
            } catch {
                continue
            }
        }
        
        await MainActor.run {
            self.currentSubscription = finalSubscription
        }
    }
    
    // MARK: - Feature Gates
    
    public func canAccessFeature(_ feature: Feature) -> Bool {
        guard let sub = currentSubscription else { return false }
        
        switch feature {
        case .unlimitedBills:
            return sub.tier != .free
        case .customRecurrence:
            return sub.tier != .free
        case .smartReminders:
            return sub.tier == .pro || sub.tier == .household || sub.tier == .enterprise
        case .spendingInsights:
            return sub.tier == .pro || sub.tier == .household || sub.tier == .enterprise
        case .taxExport:
            return sub.tier == .pro || sub.tier == .household || sub.tier == .enterprise
        case .businessTags:
            return sub.tier == .pro || sub.tier == .household || sub.tier == .enterprise
        case .advancedWidgets:
            return sub.tier == .pro || sub.tier == .household || sub.tier == .enterprise
        case .shortcutsIntegration:
            return sub.tier == .pro || sub.tier == .household || sub.tier == .enterprise
        case .householdMembers:
            return sub.tier == .household || sub.tier == .enterprise
        case .realTimeSync:
            return sub.tier == .household || sub.tier == .enterprise
        case .splitBillTracking:
            return sub.tier == .household || sub.tier == .enterprise
        case .settleUp:
            return sub.tier == .household || sub.tier == .enterprise
        case .sharedInvoiceAttachments:
            return sub.tier == .household || sub.tier == .enterprise
        }
    }
    
    public func shouldShowUpgradePrompt(for feature: Feature) -> Bool {
        guard let sub = currentSubscription else { return true }
        return sub.tier == .free && feature != .unlimitedBills
    }
    
    // MARK: - Restore
    
    public func restorePurchases() async throws {
        try await AppStore.sync()
        await updateSubscriptionStatus()
    }
    
    // MARK: - Private
    
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    await self?.updateSubscriptionStatus()
                    if let t = transaction {
                        await t.finish()
                    }
                } catch {
                    continue
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Errors

public enum SubscriptionError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed
    
    public var errorDescription: String? {
        switch self {
        case .failedVerification: return "Transaction verification failed"
        case .productNotFound: return "Product not found"
        case .purchaseFailed: return "Purchase failed"
        }
    }
}
