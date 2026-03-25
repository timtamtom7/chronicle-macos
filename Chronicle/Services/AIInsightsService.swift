import Foundation

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
