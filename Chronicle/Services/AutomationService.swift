import Foundation
import AppIntents
import WidgetKit

// MARK: - Automation Service
// Handles automation triggers for bill overdue and budget exceeded events
// Hooks into Shortcuts automation via App Intents triggers

@MainActor
final class AutomationService: ObservableObject {
    static let shared = AutomationService()
    
    @Published var lastOverdueTrigger: Date?
    @Published var lastBudgetExceededTrigger: Date?
    
    private var overdueCheckTimer: Timer?
    private var budgetCheckTimer: Timer?
    private var previouslyOverdueBills: Set<UUID> = []
    private var previouslyExceededBudget: Bool = false
    
    private init() {}
    
    // MARK: - Start/Stop Automation Monitoring
    
    func startMonitoring() {
        startOverdueMonitoring()
        startBudgetMonitoring()
    }
    
    func stopMonitoring() {
        overdueCheckTimer?.invalidate()
        overdueCheckTimer = nil
        budgetCheckTimer?.invalidate()
        budgetCheckTimer = nil
    }
    
    // MARK: - Overdue Bill Automation
    
    private func startOverdueMonitoring() {
        // Initial check
        checkForNewOverdueBills()
        
        // Check every 15 minutes
        overdueCheckTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForNewOverdueBills()
            }
        }
    }
    
    private func checkForNewOverdueBills() {
        let billStore = BillStore.shared
        let currentOverdue = Set(billStore.pastDue.map { $0.id })
        
        // Find newly overdue bills
        let newOverdue = currentOverdue.subtracting(previouslyOverdueBills)
        
        for billId in newOverdue {
            if let bill = billStore.bills.first(where: { $0.id == billId }) {
                triggerBillOverdueAutomation(bill: bill)
            }
        }
        
        previouslyOverdueBills = currentOverdue
    }
    
    /// Triggers automation when a bill becomes overdue
    /// Hooks into Shortcuts via WhenBillOverdueTrigger AppIntent
    func triggerBillOverdueAutomation(bill: Bill) {
        lastOverdueTrigger = Date()
        
        // Log the automation trigger
        print("[AutomationService] Bill overdue automation triggered for: \(bill.name)")
        
        // Send notification
        NotificationScheduler.shared.sendOverdueNotification(for: bill)
        
        // Update widget timeline to refresh
        reloadWidgets()
        
        // Post notification for app-level handling
        NotificationCenter.default.post(
            name: .billOverdueAutomationTriggered,
            object: nil,
            userInfo: ["billId": bill.id.uuidString, "billName": bill.name]
        )
    }
    
    // MARK: - Budget Exceeded Automation
    
    private func startBudgetMonitoring() {
        // Initial check
        checkForBudgetExceeded()
        
        // Check every 30 minutes
        budgetCheckTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForBudgetExceeded()
            }
        }
    }
    
    private func checkForBudgetExceeded() {
        let billStore = BillStore.shared
        let status = billStore.overallBudgetStatus
        
        guard status.limit > 0 else { return }
        
        let isExceeded = status.spent >= status.limit
        let percentUsed = (status.spent / status.limit) * 100
        
        // Check if newly exceeded (was under, now over)
        let wasExceeded = previouslyExceededBudget
        let threshold = NSDecimalNumber(decimal: status.limit).doubleValue * 0.9 // 90% threshold
        
        if isExceeded && !wasExceeded {
            triggerBudgetExceededAutomation(total: status.spent, limit: status.limit, percentage: percentUsed)
        } else if !isExceeded && wasExceeded {
            // Budget no longer exceeded
            previouslyExceededBudget = false
        }
        
        previouslyExceededBudget = isExceeded
    }
    
    /// Triggers automation when monthly spending exceeds budget threshold
    /// Hooks into Shortcuts via WhenBudgetExceededTrigger AppIntent
    func triggerBudgetExceededAutomation(total: Decimal, limit: Decimal, percentage: Decimal) {
        lastBudgetExceededTrigger = Date()
        
        // Log the automation trigger
        let percentDouble = (percentage as NSDecimalNumber).doubleValue
        let totalDouble = (total as NSDecimalNumber).doubleValue
        let limitDouble = (limit as NSDecimalNumber).doubleValue
        print("[AutomationService] Budget exceeded automation triggered: \(String(format: "%.0f", percentDouble))% ($\(String(format: "%.2f", totalDouble)) of $\(String(format: "%.2f", limitDouble)))")
        
        // Update widget timeline to refresh
        reloadWidgets()
        
        // Post notification for app-level handling
        NotificationCenter.default.post(
            name: .budgetExceededAutomationTriggered,
            object: nil,
            userInfo: [
                "total": total,
                "limit": limit,
                "percentage": percentage
            ]
        )
    }
    
    // MARK: - Widget Refresh
    
    private func reloadWidgets() {
        if #available(macOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // MARK: - Shortcuts Integration
    
    /// Returns whether a bill overdue automation was triggered recently
    func hasRecentOverdueTrigger(within minutes: Int = 5) -> Bool {
        guard let lastTrigger = lastOverdueTrigger else { return false }
        let interval = Date().timeIntervalSince(lastTrigger)
        return interval < Double(minutes * 60)
    }
    
    /// Returns whether a budget exceeded automation was triggered recently
    func hasRecentBudgetExceededTrigger(within minutes: Int = 5) -> Bool {
        guard let lastTrigger = lastBudgetExceededTrigger else { return false }
        let interval = Date().timeIntervalSince(lastTrigger)
        return interval < Double(minutes * 60)
    }
    
    /// Gets bills that became overdue since last check
    func newlyOverdueBills() -> [Bill] {
        let billStore = BillStore.shared
        return billStore.pastDue.filter { !previouslyOverdueBills.contains($0.id) }
    }
    
    /// Gets current budget status for automation
    func currentBudgetStatus() -> BudgetStatusInfo {
        let billStore = BillStore.shared
        let status = billStore.overallBudgetStatus
        return BudgetStatusInfo(
            spent: status.spent,
            limit: status.limit,
            percentage: status.spent / status.limit,
            isExceeded: status.spent >= status.limit
        )
    }
}

// MARK: - Budget Status Info

struct BudgetStatusInfo {
    let spent: Decimal
    let limit: Decimal
    let percentage: Decimal
    let isExceeded: Bool
    
    var spentFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: spent)) ?? "$0.00"
    }
    
    var limitFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: limit)) ?? "$0.00"
    }
    
    var percentageFormatted: String {
        let percentDouble = (percentage as NSDecimalNumber).doubleValue * 100
        return String(format: "%.0f%%", percentDouble)
    }
}

// MARK: - Automation Notification Names

extension Notification.Name {
    static let billOverdueAutomationTriggered = Notification.Name("billOverdueAutomationTriggered")
    static let budgetExceededAutomationTriggered = Notification.Name("budgetExceededAutomationTriggered")
}

// MARK: - Bill Store Extension for Automation

extension BillStore {
    /// Checks and triggers any automation events
    /// Call this after bill updates
    func checkAutomationEvents() {
        let _ = AutomationService.shared
    }
}

// MARK: - Shortcuts Automation Support

/// Provides dynamic options for WhenBillOverdueTrigger
@available(macOS 13.0, *)
struct BillOverdueTriggerOptionsProvider: DynamicOptionsProvider {
    @MainActor
    func results() async throws -> [String] {
        let billStore = BillStore.shared
        billStore.loadBills()
        return billStore.pastDue.map { "\($0.name) - \($0.formattedAmount)" }
    }
}

/// Provides dynamic options for WhenBudgetExceededTrigger
@available(macOS 13.0, *)
struct BudgetExceededTriggerOptionsProvider: DynamicOptionsProvider {
    @MainActor
    func results() async throws -> [String] {
        let billStore = BillStore.shared
        billStore.loadBills()
        let status = billStore.overallBudgetStatus
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let spentStr = formatter.string(from: NSDecimalNumber(decimal: status.spent)) ?? "\(status.spent)"
        let limitStr = formatter.string(from: NSDecimalNumber(decimal: status.limit)) ?? "\(status.limit)"
        return ["\(spentStr) of \(limitStr)"]
    }
}
