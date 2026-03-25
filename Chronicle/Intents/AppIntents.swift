import Foundation
import AppIntents

// MARK: - App Intents for Shortcuts Integration

// MARK: - Get Upcoming Bills Intent

@available(macOS 13.0, *)
struct GetUpcomingBillsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Upcoming Bills"
    static var description = IntentDescription("Returns a list of bills due in the next specified number of days")
    
    @Parameter(title: "Days Ahead", default: 7)
    var daysAhead: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get upcoming bills for the next \(\.$daysAhead) days")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let billStore = BillStore()
        billStore.loadBills()
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let futureDate = calendar.date(byAdding: .day, value: daysAhead, to: today) else {
            return .result(value: [])
        }
        
        let upcoming = billStore.upcomingBills.filter { $0.dueDate >= today && $0.dueDate <= futureDate }
        
        let result = upcoming.map { bill -> String in
            let dueFormatter = DateFormatter()
            dueFormatter.dateStyle = .short
            dueFormatter.timeStyle = .none
            let dueStr = dueFormatter.string(from: bill.dueDate)
            return "\(bill.name): \(bill.formattedAmount) due \(dueStr)"
        }
        
        return .result(value: result)
    }
}

// MARK: - Add Bill Intent

@available(macOS 13.0, *)
struct AddBillIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Bill to Chronicle"
    static var description = IntentDescription("Adds a new bill to Chronicle")
    
    @Parameter(title: "Bill Name")
    var name: String
    
    @Parameter(title: "Amount (dollars)")
    var amount: Double
    
    @Parameter(title: "Due Day of Month")
    var dueDay: Int
    
    @Parameter(title: "Category", default: "Other")
    var categoryName: String
    
    @Parameter(title: "Recurrence", default: "Monthly")
    var recurrenceName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Add bill \(\.$name) for \(\.$amount) due on day \(\.$dueDay)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let category = Category(rawValue: categoryName) ?? .other
        let recurrence = Recurrence(rawValue: recurrenceName) ?? .monthly
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: Date())
        components.day = min(dueDay, 28) // Cap at 28 for safety
        let dueDate = calendar.date(from: components) ?? Date()
        
        let amountCents = Int(amount * 100)
        
        let bill = Bill(
            name: name,
            amountCents: amountCents,
            dueDay: dueDay,
            dueDate: dueDate,
            recurrence: recurrence,
            category: category
        )
        
        let billStore = BillStore()
        billStore.addBill(bill)
        
        return .result(dialog: "Added \(name) for $\(String(format: "%.2f", amount)) due on day \(dueDay)")
    }
}

// MARK: - Mark Bill Paid Intent

@available(macOS 13.0, *)
struct MarkBillPaidIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Bill as Paid"
    static var description = IntentDescription("Marks a specific bill as paid")
    
    @Parameter(title: "Bill Name")
    var billName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$billName) as paid")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let billStore = BillStore()
        billStore.loadBills()
        
        guard let bill = billStore.bills.first(where: { $0.name.localizedCaseInsensitiveContains(billName) && !$0.isPaid }) else {
            return .result(dialog: "No unpaid bill found matching '\(billName)'")
        }
        
        billStore.markPaid(bill, paid: true)
        
        return .result(dialog: "Marked '\(bill.name)' as paid")
    }
}

// MARK: - Get Monthly Total Intent

@available(macOS 13.0, *)
struct GetMonthlyTotalIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Monthly Bills Total"
    static var description = IntentDescription("Returns the total of all bills for the current month")
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> {
        let billStore = BillStore()
        billStore.loadBills()
        
        let total = billStore.totalDueThisMonth
        return .result(value: NSDecimalNumber(decimal: total).doubleValue)
    }
}

// MARK: - Get Bill Status Intent

@available(macOS 13.0, *)
struct GetBillStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Bill Status"
    static var description = IntentDescription("Returns the payment status of a specific bill")
    
    @Parameter(title: "Bill Name")
    var billName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get status of \(\.$billName)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let billStore = BillStore()
        billStore.loadBills()
        
        guard let bill = billStore.bills.first(where: { $0.name.localizedCaseInsensitiveContains(billName) }) else {
            return .result(value: "Bill not found")
        }
        
        let status: String
        if bill.isPaid {
            status = "Paid"
        } else {
            let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: bill.dueDate).day ?? 0
            if daysUntilDue < 0 {
                status = "Overdue by \(abs(daysUntilDue)) days"
            } else if daysUntilDue == 0 {
                status = "Due today"
            } else {
                status = "Due in \(daysUntilDue) days"
            }
        }
        
        return .result(value: "\(bill.name): \(status) — \(bill.formattedAmount)")
    }
}

// MARK: - App Shortcuts Provider

@available(macOS 13.0, *)
struct ChronicleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetUpcomingBillsIntent(),
            phrases: [
                "Get upcoming bills in \(.applicationName)",
                "What bills are due in \(.applicationName)",
                "List my bills from \(.applicationName)"
            ],
            shortTitle: "Get Upcoming Bills",
            systemImageName: "list.bullet.rectangle"
        )
        
        AppShortcut(
            intent: AddBillIntent(),
            phrases: [
                "Add a bill to \(.applicationName)",
                "Create new bill in \(.applicationName)",
                "Track a new payment in \(.applicationName)"
            ],
            shortTitle: "Add Bill",
            systemImageName: "plus.circle"
        )
        
        AppShortcut(
            intent: MarkBillPaidIntent(),
            phrases: [
                "Mark bill as paid in \(.applicationName)",
                "Record payment in \(.applicationName)"
            ],
            shortTitle: "Mark Paid",
            systemImageName: "checkmark.circle"
        )
        
        AppShortcut(
            intent: GetMonthlyTotalIntent(),
            phrases: [
                "How much are my bills this month in \(.applicationName)",
                "Total bills from \(.applicationName)"
            ],
            shortTitle: "Monthly Total",
            systemImageName: "dollarsign.circle"
        )
    }
}
