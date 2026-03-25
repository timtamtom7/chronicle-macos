import Foundation

/// Generates AI-powered insights about bill payment patterns and trends
final class InsightsGenerator {
    static let shared = InsightsGenerator()
    
    private init() {}
    
    // MARK: - Insight Types
    
    enum InsightType {
        case paymentPattern
        case budgetAlert
        case savingsTip
        case anomaly
        case trend
    }
    
    struct Insight: Identifiable {
        let id = UUID()
        let type: InsightType
        let title: String
        let body: String
        let category: Category?
        let severity: Severity
        
        enum Severity {
            case info
            case warning
            case critical
        }
    }
    
    // MARK: - Generate Insights
    
    /// Generate insights from bill history
    func generateInsights(from bills: [Bill], paymentRecords: [PaymentRecord]) -> [Insight] {
        var insights: [Insight] = []
        
        // Payment timing patterns
        let paymentTimingInsights = analyzePaymentTiming(paymentRecords: paymentRecords, bills: bills)
        insights.append(contentsOf: paymentTimingInsights)
        
        // Category spending insights
        let categoryInsights = analyzeCategorySpending(bills: bills)
        insights.append(contentsOf: categoryInsights)
        
        // Upcoming month insights
        let upcomingInsights = analyzeUpcomingBills(bills: bills)
        insights.append(contentsOf: upcomingInsights)
        
        // Anomaly detection
        let anomalyInsights = detectAnomalies(bills: bills, paymentRecords: paymentRecords)
        insights.append(contentsOf: anomalyInsights)
        
        return insights
    }
    
    // MARK: - Payment Timing Analysis
    
    private func analyzePaymentTiming(paymentRecords: [PaymentRecord], bills: [Bill]) -> [Insight] {
        var insights: [Insight] = []
        
        // Group payments by day-of-month
        var paymentsByDay: [Int: [PaymentRecord]] = [:]
        for record in paymentRecords {
            let day = Calendar.current.component(.day, from: record.paidAt)
            paymentsByDay[day, default: []].append(record)
        }
        
        // Find most common payment day
        guard let mostCommonDay = paymentsByDay.max(by: { $0.value.count < $1.value.count })?.key else {
            return insights
        }
        
        if paymentsByDay[mostCommonDay]?.count ?? 0 >= 3 {
            let message = String(localized: "Based on your history, you typically pay bills around day \(mostCommonDay) of each month. Consider scheduling payment reminders a few days before.")
            insights.append(Insight(
                type: .paymentPattern,
                title: String(localized: "Payment Pattern Detected"),
                body: message,
                category: nil,
                severity: .info
            ))
        }
        
        // Average time between due date and payment
        var daysBetweenDues: [Int] = []
        for record in paymentRecords {
            if let bill = bills.first(where: { $0.id == record.billId }) {
                let dueDayOfMonth = Calendar.current.component(.day, from: bill.dueDate)
                let paidDayOfMonth = Calendar.current.component(.day, from: record.paidAt)
                let daysDiff = paidDayOfMonth - dueDayOfMonth
                daysBetweenDues.append(daysDiff)
            }
        }
        
        if !daysBetweenDues.isEmpty {
            let avgDays = daysBetweenDues.reduce(0, +) / daysBetweenDues.count
            if avgDays < -2 {
                insights.append(Insight(
                    type: .trend,
                    title: String(localized: "Early Payer"),
                    body: String(localized: "You typically pay bills \(abs(avgDays)) days before the due date. Great job staying ahead!"),
                    category: nil,
                    severity: .info
                ))
            } else if avgDays > 2 {
                insights.append(Insight(
                    type: .trend,
                    title: String(localized: "Payments Often Late"),
                    body: String(localized: "You typically pay bills \(avgDays) days after the due date. Consider setting reminders earlier to avoid late fees."),
                    category: nil,
                    severity: .warning
                ))
            }
        }
        
        return insights
    }
    
    // MARK: - Category Spending Analysis
    
    private func analyzeCategorySpending(bills: [Bill]) -> [Insight] {
        var insights: [Insight] = []
        
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
        
        // Current month bills
        let currentMonthBills = bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd && !$0.isPaid }
        
        // Group by category
        var categoryTotals: [Category: Decimal] = [:]
        for bill in currentMonthBills {
            categoryTotals[bill.category, default: 0] += bill.amount
        }
        
        // Find largest category
        if let largest = categoryTotals.max(by: { $0.value < $1.value }) {
            let percentage = (largest.value / (categoryTotals.values.reduce(0, +) + 1)) * 100
            if percentage > 50 {
                insights.append(Insight(
                    type: .budgetAlert,
                    title: String(localized: "\(largest.key.rawValue) Dominates Spending"),
                    body: String(localized: "\(largest.key.rawValue) bills make up \(Int(NSDecimalNumber(decimal: percentage).doubleValue))% of your monthly bills. Review if this allocation works for you."),
                    category: largest.key,
                    severity: .info
                ))
            }
        }
        
        return insights
    }
    
    // MARK: - Upcoming Bills Analysis
    
    private func analyzeUpcomingBills(bills: [Bill]) -> [Insight] {
        var insights: [Insight] = []
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Bills due in next 7 days
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: today) else { return insights }
        let upcoming = bills.filter { !$0.isPaid && $0.dueDate >= today && $0.dueDate <= weekEnd }
        
        if upcoming.count >= 5 {
            let totalAmount = upcoming.reduce(Decimal(0)) { $0 + $1.amount }
            insights.append(Insight(
                type: .budgetAlert,
                title: String(localized: "Heavy Week Ahead"),
                body: String(localized: "You have \(upcoming.count) bills due in the next week totaling \(formatAmount(totalAmount)). Plan your cash flow accordingly."),
                category: nil,
                severity: .warning
            ))
        }
        
        // Find the most expensive upcoming bill
        if let mostExpensive = upcoming.max(by: { $0.amount < $1.amount }) {
            if mostExpensive.amount > 200 {
                insights.append(Insight(
                    type: .budgetAlert,
                    title: String(localized: "Large Bill Upcoming"),
                    body: String(localized: "Your \(mostExpensive.name) bill for \(formatAmount(mostExpensive.amount)) is due \(formatDate(mostExpensive.dueDate)). Ensure you have funds set aside."),
                    category: mostExpensive.category,
                    severity: .info
                ))
            }
        }
        
        return insights
    }
    
    // MARK: - Anomaly Detection
    
    private func detectAnomalies(bills: [Bill], paymentRecords: [PaymentRecord]) -> [Insight] {
        var insights: [Insight] = []
        
        // Detect bills that have inconsistent payment patterns (sometimes paid, sometimes not)
        let calendar = Calendar.current
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: Date())!
        
        let recentRecords = paymentRecords.filter { $0.paidAt >= sixMonthsAgo }
        
        // Count payments per bill
        var paymentsPerBill: [UUID: Int] = [:]
        for record in recentRecords {
            paymentsPerBill[record.billId, default: 0] += 1
        }
        
        for (billId, count) in paymentsPerBill {
            guard let bill = bills.first(where: { $0.id == billId }) else { continue }
            
            // Check if recurring bill has irregular payment pattern
            if bill.recurrence != .none {
                // For monthly bills, expect 6 payments in 6 months
                let expectedPayments: Int
                switch bill.recurrence {
                case .monthly: expectedPayments = 6
                case .quarterly: expectedPayments = 2
                case .annual: expectedPayments = 1
                default: expectedPayments = 6
                }
                
                if abs(count - expectedPayments) > 2 {
                    insights.append(Insight(
                        type: .anomaly,
                        title: String(localized: "Irregular Payment Pattern"),
                        body: String(localized: "\(bill.name) has been paid only \(count) times in the past 6 months, which is unusual for a \(bill.recurrence.rawValue.lowercased()) bill."),
                        category: bill.category,
                        severity: .warning
                    ))
                }
            }
        }
        
        return insights
    }
    
    // MARK: - Helpers
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
