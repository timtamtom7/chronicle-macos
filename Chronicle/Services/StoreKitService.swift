import Foundation
import StoreKit

/// R16: StoreKit 2 integration for Chronicle subscriptions.
/// Handles product loading, purchases, and entitlement queries.
@available(macOS 13.0, *)
public final class StoreKitService: ObservableObject {
    
    public static let shared = StoreKitService()
    
    // MARK: - Published State
    
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var purchaseError: String?
    
    // MARK: - Product IDs
    
    public enum ProductID: String, CaseIterable {
        case proMonthly = "chronicle.pro.monthly"
        case proYearly = "chronicle.pro.yearly"
        case householdMonthly = "chronicle.household.monthly"
        case householdYearly = "chronicle.household.yearly"
        
        public var tier: SubscriptionTier {
            switch self {
            case .proMonthly, .proYearly: return .pro
            case .householdMonthly, .householdYearly: return .household
            }
        }
        
        public var isMonthly: Bool {
            switch self {
            case .proMonthly, .householdMonthly: return true
            case .proYearly, .householdYearly: return false
            }
        }
        
        public var displayPrice: String {
            switch self {
            case .proMonthly: return "$2.99/mo"
            case .proYearly: return "$19.99/yr"
            case .householdMonthly: return "$5.99/mo"
            case .householdYearly: return "$39.99/yr"
            }
        }
    }
    
    // MARK: - Internal State
    
    public private(set) var subscriptionExpiresAt: Date?
    public private(set) var activeTransactionID: String?
    
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Init
    
    private init() {
        updateListenerTask = listenForTransactionUpdates()
        Task { await loadProducts() }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public API
    
    /// Loads available subscription products from StoreKit.
    public func loadProducts() async {
        await MainActor.run { isLoading = true }
        
        do {
            let ids = ProductID.allCases.map { $0.rawValue }
            let loaded = try await Product.products(for: ids)
            
            await MainActor.run {
                self.products = loaded.sorted { $0.price < $1.price }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.purchaseError = "Failed to load products: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Resolves the best available product for a given tier (prefers yearly if available).
    public func product(for tier: SubscriptionTier) async throws -> Product {
        let candidates: [ProductID]
        switch tier {
        case .pro:
            candidates = [.proYearly, .proMonthly]
        case .household:
            candidates = [.householdYearly, .householdMonthly]
        default:
            throw StoreKitError.tierNotAvailable
        }
        
        // Find in loaded products
        for candidateID in candidates {
            if let product = products.first(where: { $0.id == candidateID.rawValue }) {
                return product
            }
        }
        
        // Fallback: try loading fresh
        await loadProducts()
        for candidateID in candidates {
            if let product = products.first(where: { $0.id == candidateID.rawValue }) {
                return product
            }
        }
        
        throw StoreKitError.productNotFound
    }
    
    /// Purchases the given product and returns the transaction if successful.
    public func purchase(product: Product) async throws -> Transaction? {
        await MainActor.run { purchaseError = nil }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionState(from: transaction)
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
    
    /// Queries Transaction.currentEntitlements and returns the active tier, if any.
    public func checkSubscriptionStatus() async -> SubscriptionTier? {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID == ProductID.proMonthly.rawValue ||
                   transaction.productID == ProductID.proYearly.rawValue {
                    subscriptionExpiresAt = transaction.expirationDate
                    activeTransactionID = String(transaction.id)
                    return .pro
                }
                
                if transaction.productID == ProductID.householdMonthly.rawValue ||
                   transaction.productID == ProductID.householdYearly.rawValue {
                    subscriptionExpiresAt = transaction.expirationDate
                    activeTransactionID = String(transaction.id)
                    return .household
                }
            } catch {
                continue
            }
        }
        return nil
    }
    
    /// Restores purchases via AppStore.sync().
    public func restorePurchases() async throws {
        try await AppStore.sync()
    }
    
    // MARK: - Private
    
    private func updateSubscriptionState(from transaction: Transaction) async {
        let tier: SubscriptionTier?
        switch transaction.productID {
        case ProductID.proMonthly.rawValue, ProductID.proYearly.rawValue:
            tier = .pro
        case ProductID.householdMonthly.rawValue, ProductID.householdYearly.rawValue:
            tier = .household
        default:
            tier = nil
        }
        
        subscriptionExpiresAt = transaction.expirationDate
        activeTransactionID = String(transaction.id)
        
        // Notify SubscriptionService to refresh
        await SubscriptionService.shared.refreshStatus()
    }
    
    private func listenForTransactionUpdates() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    guard let transaction = try self?.checkVerified(result) else { continue }
                    await self?.updateSubscriptionState(from: transaction)
                    await transaction.finish()
                } catch {
                    continue
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Errors

public enum StoreKitError: Error, LocalizedError {
    case productNotFound
    case failedVerification
    case purchaseFailed
    case tierNotAvailable
    
    public var errorDescription: String? {
        switch self {
        case .productNotFound: return "Subscription product not found in StoreKit."
        case .failedVerification: return "Transaction verification failed."
        case .purchaseFailed: return "Purchase could not be completed."
        case .tierNotAvailable: return "Selected subscription tier is not available."
        }
    }
}
