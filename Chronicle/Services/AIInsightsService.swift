import Foundation
import UserNotifications

/// Central service for AI-powered insights and bill intelligence
@MainActor
final class AIInsightsService: ObservableObject {
    static let shared = AIInsightsService()

    @Published private(set) var currentInsights: [InsightsGenerator.Insight] = []
    @Published private(set) var isGeneratingInsights: Bool = false

    private let insightsGenerator = InsightsGenerator.shared
    private let categorizationEngine = CategorizationEngine.shared
    private let duplicateDetector = DuplicateDetector.shared

    private init() {}

    // MARK: - Budget Risk

    struct BudgetRisk {
        enum RiskLevel: String {
            case low, medium, high, critical
        }

        let level: RiskLevel
        let predictedTotal: Decimal
        let percentOfBudgetUsed: Double
        let message: String
    }

    /// Check budget risk for the current month based on bills, payment history, and monthly budget.
    func checkBudgetRisk(bills: [Bill], paymentRecords: [PaymentRecord], monthlyBudget: Decimal) -> BudgetRisk {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!

        // Total paid this month
        let paidThisMonth = paymentRecords
            .filter { $0.paidAt >= monthStart && $0.paidAt <= monthEnd }
            .reduce(Decimal(0)) { $0 + $1.amount }

        // Bills due this month (paid + unpaid)
        let monthBills = bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd }
        let totalDueThisMonth = monthBills.reduce(Decimal(0)) { $0 + $1.amount }
        let paidSoFar = monthBills.filter { $0.isPaid }.reduce(Decimal(0)) { $0 + $1.amount }
        let remaining = totalDueThisMonth - paidSoFar

        // Historical trend: average of past 3 months
        var historicalTotals: [Decimal] = []
        for i in 1...3 {
            guard let histMonthStart = calendar.date(byAdding: .month, value: -i, to: monthStart),
                  let histMonthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: histMonthStart) else {
                continue
            }
            let histTotal = paymentRecords
                .filter { $0.paidAt >= histMonthStart && $0.paidAt <= histMonthEnd }
                .reduce(Decimal(0)) { $0 + $1.amount }
            historicalTotals.append(histTotal)
        }

        let avgHistorical = historicalTotals.isEmpty ? totalDueThisMonth : historicalTotals.reduce(0, +) / Decimal(historicalTotals.count)

        // Predict end-of-month: paid so far + avg historical remaining
        let predictedTotal = paidSoFar + remaining
        let effectivePredicted = max(predictedTotal, avgHistorical)

        let percentUsed = monthlyBudget > 0 ? NSDecimalNumber(decimal: effectivePredicted / monthlyBudget).doubleValue : 0.0
        let percentClamped = min(percentUsed, 2.0) // cap at 200%

        // Determine risk level
        let level: BudgetRisk.RiskLevel
        let message: String

        if percentClamped >= 1.2 {
            level = .critical
            message = "You are projected to exceed your budget by \(Int((percentClamped - 1.0) * 100))%. Consider pausing non-essential bills."
        } else if percentClamped >= 1.0 {
            level = .high
            message = "You are projected to hit your budget limit this month. Review upcoming bills."
        } else if percentClamped >= 0.8 {
            level = .medium
            message = "You've used \(Int(percentClamped * 100))% of your monthly budget. \(Int(NSDecimalNumber(decimal: monthlyBudget - effectivePredicted).doubleValue)) remaining."
        } else {
            level = .low
            message = "On track with \(Int(NSDecimalNumber(decimal: monthlyBudget - effectivePredicted).doubleValue)) of your budget remaining."
        }

        return BudgetRisk(
            level: level,
            predictedTotal: effectivePredicted,
            percentOfBudgetUsed: percentClamped * 100,
            message: message
        )
    }

    /// Send a budget alert notification if risk is HIGH or CRITICAL.
    func sendBudgetAlertIfNeeded(bills: [Bill], paymentRecords: [PaymentRecord], monthlyBudget: Decimal) {
        let risk = checkBudgetRisk(bills: bills, paymentRecords: paymentRecords, monthlyBudget: monthlyBudget)

        guard risk.level == .high || risk.level == .critical else { return }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let predictedStr = formatter.string(from: NSDecimalNumber(decimal: risk.predictedTotal)) ?? "$0.00"

        let content = UNMutableNotificationContent()
        content.title = "Chronicle"
        content.body = "Budget Alert: You are projected to spend \(predictedStr) this month. \(risk.message)"
        content.sound = .default
        content.categoryIdentifier = "BUDGET_ALERT"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "budget_alert_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send budget alert: \(error)")
            }
        }
    }
    
    // MARK: - Insight Generation
    
    /// Generate all AI insights from current bill data
    func generateInsights(bills: [Bill], paymentRecords: [PaymentRecord]) {
        isGeneratingInsights = true
        currentInsights = insightsGenerator.generateInsights(from: bills, paymentRecords: paymentRecords)
        isGeneratingInsights = false
    }
    
    // MARK: - Categorization
    
    /// Suggest a category for a new bill
    func suggestCategory(for billName: String) -> Category {
        return categorizationEngine.suggestCategory(for: billName)
    }
    
    /// Learn from a user's category correction
    func learnCategoryCorrection(billName: String, correctedCategory: Category) {
        categorizationEngine.learnFromCorrection(billName: billName, correctedCategory: correctedCategory)
    }
    
    // MARK: - Duplicate Detection
    
    /// Check if a new bill might be a duplicate
    func checkForDuplicate(
        name: String,
        amount: Decimal,
        dueDate: Date,
        currency: Currency,
        existingBills: [Bill],
        excludeBillId: UUID? = nil
    ) -> DuplicateDetector.DuplicateMatch? {
        return duplicateDetector.checkDuplicate(
            newBillName: name,
            newAmount: amount,
            newDueDate: dueDate,
            currency: currency,
            existingBills: existingBills,
            excludeBillId: excludeBillId
        )
    }
    
    // MARK: - Predictive Reminders
    
    /// Calculate optimal reminder timing based on user's payment history
    func optimalReminderTiming(for bill: Bill, paymentRecords: [PaymentRecord]) -> ReminderTiming {
        let billPayments = paymentRecords.filter { $0.billId == bill.id }
        guard !billPayments.isEmpty else {
            return .oneDay // Default
        }
        
        // Calculate average days before due date that user pays
        var avgDaysBefore: Double = 0
        for record in billPayments {
            let dueDay = Calendar.current.component(.day, from: bill.dueDate)
            let paidDay = Calendar.current.component(.day, from: record.paidAt)
            avgDaysBefore += Double(dueDay - paidDay)
        }
        avgDaysBefore /= Double(billPayments.count)
        
        // Return appropriate reminder timing
        if avgDaysBefore >= 3 {
            return .threeDays
        } else if avgDaysBefore >= 1 {
            return .oneDay
        } else {
            return .dueDate
        }
    }
    
    // MARK: - Monthly Summary
    
    /// Generate a monthly summary string
    func monthlySummary(bills: [Bill]) -> String {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
        
        let monthBills = bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd }
        let paidBills = monthBills.filter { $0.isPaid }
        let unpaidBills = monthBills.filter { !$0.isPaid }
        
        let totalPaid = paidBills.reduce(Decimal(0)) { $0 + $1.amount }
        let totalUnpaid = unpaidBills.reduce(Decimal(0)) { $0 + $1.amount }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let paidStr = formatter.string(from: NSDecimalNumber(decimal: totalPaid)) ?? "$0.00"
        let unpaidStr = formatter.string(from: NSDecimalNumber(decimal: totalUnpaid)) ?? "$0.00"
        
        let monthNameFormatter = DateFormatter()
        monthNameFormatter.dateFormat = "MMMM"
        let monthName = monthNameFormatter.string(from: now)
        
        return String(localized: "\(monthName) Summary: \(paidBills.count) bills paid (\(paidStr)), \(unpaidBills.count) bills remaining (\(unpaidStr))")
    }
}
