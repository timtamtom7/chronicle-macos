import Foundation
import AppIntents

// MARK: - App Intents for Shortcuts Integration (R11 + R18 expanded)

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
        let billStore = BillStore.shared
        billStore.loadBills()
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let futureDate = calendar.date(byAdding: .day, value: daysAhead, to: today) else {
            return .result(value: [])
        }
        
        let upcoming = billStore.bills.filter { $0.dueDate >= today && $0.dueDate <= futureDate && !$0.isPaid }
        
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
    
    @Parameter(title: "Name")
    var name: String
    
    @Parameter(title: "Amount")
    var amount: Double
    
    @Parameter(title: "Due Date")
    var dueDate: Date
    
    @Parameter(title: "Category", default: "Other")
    var categoryName: String
    
    @Parameter(title: "Recurrence", default: "none")
    var recurrenceName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Add bill \(\.$name) for \(\.$amount) due \(\.$dueDate)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let billStore = BillStore.shared
        billStore.loadBills()
        
        let calendar = Calendar.current
        let dueDay = calendar.component(.day, from: dueDate)
        let amountCents = Int(amount * 100)
        
        // Parse category
        let category = Category.allCases.first { 
            $0.rawValue.lowercased() == categoryName.lowercased() 
        } ?? .other
        
        // Parse recurrence
        let recurrence = Recurrence.allCases.first { 
            $0.rawValue.lowercased() == recurrenceName.lowercased() 
        } ?? .none
        
        let bill = Bill(
            name: name,
            amountCents: amountCents,
            dueDay: dueDay,
            dueDate: dueDate,
            recurrence: recurrence,
            category: category
        )
        
        billStore.addBill(bill)
        
        return .result(dialog: "Added bill '\(name)' for $\(String(format: "%.2f", amount))")
    }
}

// MARK: - Mark Bill as Paid Intent

@available(macOS 13.0, *)
struct MarkBillPaidIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Bill as Paid"
    static var description = IntentDescription("Marks a specific bill as paid")
    
    @Parameter(title: "Bill Name")
    var billName: String
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let billStore = BillStore.shared
        billStore.loadBills()
        
        if let index = billStore.bills.firstIndex(where: { $0.name.localizedCaseInsensitiveContains(billName) && !$0.isPaid }) {
            var bill = billStore.bills[index]
            bill.isPaid = true
            billStore.updateBill(bill)
            return .result(dialog: "Marked '\(bill.name)' as paid")
        } else {
            return .result(dialog: "Could not find unpaid bill matching '\(billName)'")
        }
    }
}

// MARK: - Get Monthly Spending Intent (R18)

@available(macOS 13.0, *)
struct GetMonthlySpendingIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Monthly Spending Total"
    static var description = IntentDescription("Returns the total amount spent on bills this month")
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> {
        let billStore = BillStore.shared
        billStore.loadBills()
        
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        
        let monthlyTotal = billStore.bills
            .filter { $0.isPaid }
            .reduce(0.0) { total, bill in
                guard bill.dueDate >= startOfMonth && bill.dueDate <= now else { return total }
                return total + (Decimal(bill.amountCents) / 100 as Decimal as NSDecimalNumber).doubleValue
            }
        
        return .result(value: monthlyTotal)
    }
}

// MARK: - Get Spending by Category Intent (R18)

@available(macOS 13.0, *)
struct GetSpendingByCategoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Spending by Category"
    static var description = IntentDescription("Returns spending totals grouped by category as a formatted string")
    
    @Parameter(title: "Month Offset", default: 0)
    var monthOffset: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get spending by category for month offset \(\.$monthOffset)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let billStore = BillStore.shared
        billStore.loadBills()
        
        let calendar = Calendar.current
        let now = Date()
        guard let targetMonth = calendar.date(byAdding: .month, value: -monthOffset, to: now),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: targetMonth)),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return .result(value: "Error calculating month range")
        }
        
        var spending: [String: Double] = [:]
        for bill in billStore.bills where bill.isPaid {
            guard bill.dueDate >= startOfMonth && bill.dueDate < endOfMonth else { continue }
            let categoryName = bill.category.rawValue
            let amount = (Decimal(bill.amountCents) / 100 as Decimal as NSDecimalNumber).doubleValue
            spending[categoryName, default: 0] += amount
        }
        
        // Format as readable string
        let lines = spending.sorted { $0.value > $1.value }.map { category, amount in
            "\(category): $\(String(format: "%.2f", amount))"
        }
        let result = lines.isEmpty ? "No spending recorded" : lines.joined(separator: "\n")
        
        return .result(value: result)
    }
}

// MARK: - Create Bill from Text Intent (R18)

@available(macOS 13.0, *)
struct CreateBillFromTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Bill from Text"
    static var description = IntentDescription("Parses natural language text to create a bill")
    
    @Parameter(title: "Text")
    var text: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Create bill from: \(\.$text)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let billStore = BillStore.shared
        billStore.loadBills()
        
        // Simple parser: "Netflix $15.99 monthly on the 15th"
        let amountPattern = #"\$?(\d+\.?\d*)"#
        let amountRegex = try? NSRegularExpression(pattern: amountPattern)
        let amountRange = NSRange(text.startIndex..., in: text)
        var extractedAmount: Double = 0
        
        if let match = amountRegex?.firstMatch(in: text, range: amountRange),
           let range = Range(match.range(at: 1), in: text) {
            extractedAmount = Double(String(text[range])) ?? 0
        }
        
        // Extract name (first word before $ or quoted)
        var extractedName = "Parsed Bill"
        if let dollarSign = text.firstIndex(of: "$") {
            let nameStart = text.startIndex
            let nameEnd = dollarSign
            if nameStart < nameEnd {
                extractedName = String(text[nameStart..<nameEnd]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Default due date = today + 7 days
        let dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let dueDay = Calendar.current.component(.day, from: dueDate)
        
        let bill = Bill(
            name: extractedName.isEmpty ? "Parsed Bill" : extractedName,
            amountCents: Int(extractedAmount * 100),
            dueDay: dueDay,
            dueDate: dueDate,
            recurrence: .none,
            category: .other
        )
        
        billStore.addBill(bill)
        
        return .result(dialog: "Created bill '\(extractedName)' for $\(String(format: "%.2f", extractedAmount))")
    }
}

// MARK: - R18 New Intents

// MARK: - Get Overdue Bills Intent

@available(macOS 13.0, *)
struct GetOverdueBillsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Overdue Bills"
    static var description = IntentDescription("Returns all overdue unpaid bills from Chronicle")
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let billStore = BillStore.shared
        billStore.loadBills()
        
        let overdue = billStore.pastDue
        
        let result = overdue.map { bill -> String in
            let dueFormatter = DateFormatter()
            dueFormatter.dateStyle = .medium
            dueFormatter.timeStyle = .none
            let dueStr = dueFormatter.string(from: bill.dueDate)
            return "\(bill.name): \(bill.formattedAmount) (was due \(dueStr))"
        }
        
        return .result(value: result)
    }
}

// MARK: - Get Bill Details Intent

@available(macOS 13.0, *)
struct GetBillDetailsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Bill Details"
    static var description = IntentDescription("Returns full details for a specific bill as JSON")
    
    @Parameter(title: "Bill Name")
    var billName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get details for bill: \(\.$billName)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let billStore = BillStore.shared
        billStore.loadBills()
        
        guard let bill = billStore.bills.first(where: { $0.name.localizedCaseInsensitiveContains(billName) }) else {
            return .result(value: "{\"error\": \"Bill not found\"}")
        }
        
        let dueFormatter = ISO8601DateFormatter()
        dueFormatter.formatOptions = [.withInternetDateTime]
        
        let details: [String: Any] = [
            "id": bill.id.uuidString,
            "name": bill.name,
            "amount": (Decimal(bill.amountCents) / 100 as Decimal as NSDecimalNumber).doubleValue,
            "currency": bill.currency.rawValue,
            "dueDate": dueFormatter.string(from: bill.dueDate),
            "dueDay": bill.dueDay,
            "category": bill.category.rawValue,
            "recurrence": bill.recurrence.rawValue,
            "isPaid": bill.isPaid,
            "isActive": bill.isActive,
            "isTaxDeductible": bill.isTaxDeductible,
            "notes": bill.notes ?? "",
            "createdAt": dueFormatter.string(from: bill.createdAt)
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: details, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return .result(value: "{\"error\": \"Failed to serialize bill details\"}")
        }
        
        return .result(value: jsonString)
    }
}

// MARK: - Set Budget Intent

@available(macOS 13.0, *)
struct SetBudgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Monthly Budget"
    static var description = IntentDescription("Sets the monthly budget amount in Chronicle")
    
    @Parameter(title: "Budget Amount")
    var budgetAmount: Double
    
    static var parameterSummary: some ParameterSummary {
        Summary("Set monthly budget to $\(\.$budgetAmount)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let billStore = BillStore.shared
        billStore.loadBills()
        
        let amount = Decimal(budgetAmount)
        billStore.setMonthlyBudget(amount)
        
        return .result(dialog: "Monthly budget set to $\(String(format: "%.2f", budgetAmount))")
    }
}

// MARK: - Get Budget Status Intent

@available(macOS 13.0, *)
struct GetBudgetStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Budget Status"
    static var description = IntentDescription("Returns current spend vs budget percentage")
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let billStore = BillStore.shared
        billStore.loadBills()
        
        let status = billStore.overallBudgetStatus
        guard status.limit > 0 else {
            return .result(value: "No budget set")
        }
        
        let percentage = (status.spent / status.limit) * 100
        let remaining = status.limit - status.spent
        
        let result = String(format: "%.0f%% of budget used (%.2f spent, %.2f remaining)",
                          (percentage as NSDecimalNumber).doubleValue,
                          (status.spent as NSDecimalNumber).doubleValue,
                          (remaining as NSDecimalNumber).doubleValue)
        
        return .result(value: result)
    }
}

// MARK: - When Bill Overdue Trigger (AppIntent Trigger for Shortcuts Automation)

@available(macOS 13.0, *)
struct WhenBillOverdueTrigger: AppIntent {
    static var title: LocalizedStringResource = "When a Bill Becomes Overdue"
    static var description = IntentDescription("Triggers when any bill crosses its due date without payment")
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // This trigger is used by Shortcuts automation
        // The actual trigger logic is handled by AutomationService
        return .result()
    }
}

// MARK: - When Budget Exceeded Trigger (AppIntent Trigger for Shortcuts Automation)

@available(macOS 13.0, *)
struct WhenBudgetExceededTrigger: AppIntent {
    static var title: LocalizedStringResource = "When Budget Exceeded"
    static var description = IntentDescription("Triggers when monthly spending exceeds the set budget")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Threshold Percentage", default: 100)
    var thresholdPercentage: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Trigger when budget exceeds \(\.$thresholdPercentage)%")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // This trigger is used by Shortcuts automation
        // The actual trigger logic is handled by AutomationService
        return .result()
    }
}

// MARK: - App Shortcuts Provider (R18 + R11 Siri Suggestions)

@available(macOS 13.0, *)
struct ChronicleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Get Upcoming Bills
        AppShortcut(
            intent: GetUpcomingBillsIntent(),
            phrases: [
                "Get upcoming bills in \(.applicationName)",
                "Show my bills in \(.applicationName)"
            ],
            shortTitle: "Upcoming Bills",
            systemImageName: "list.bullet"
        )
        
        // Get Monthly Spending
        AppShortcut(
            intent: GetMonthlySpendingIntent(),
            phrases: [
                "How much have I spent this month in \(.applicationName)",
                "How much have I spent this month on \(.applicationName)",
                "Monthly spending in \(.applicationName)"
            ],
            shortTitle: "Monthly Spending",
            systemImageName: "dollarsign.circle"
        )
        
        // Add Bill
        AppShortcut(
            intent: AddBillIntent(),
            phrases: [
                "Add a bill to \(.applicationName)",
                "Log a bill in \(.applicationName)",
                "Create new bill in \(.applicationName)"
            ],
            shortTitle: "Add Bill",
            systemImageName: "plus.circle"
        )
        
        // Mark Bill Paid
        AppShortcut(
            intent: MarkBillPaidIntent(),
            phrases: [
                "Mark bill paid in \(.applicationName)",
                "Pay a bill in \(.applicationName)"
            ],
            shortTitle: "Mark Bill Paid",
            systemImageName: "checkmark.circle"
        )
        
        // Create Bill from Text
        AppShortcut(
            intent: CreateBillFromTextIntent(),
            phrases: [
                "Create bill from text in \(.applicationName)",
                "Parse a bill in \(.applicationName)"
            ],
            shortTitle: "Create Bill from Text",
            systemImageName: "text.badge.plus"
        )
        
        // Get Spending by Category
        AppShortcut(
            intent: GetSpendingByCategoryIntent(),
            phrases: [
                "Show my spending by category in \(.applicationName)",
                "Category spending in \(.applicationName)",
                "Break down my bills by category in \(.applicationName)"
            ],
            shortTitle: "Spending by Category",
            systemImageName: "chart.pie"
        )
        
        // R18 new shortcuts
        AppShortcut(
            intent: GetOverdueBillsIntent(),
            phrases: [
                "Are any bills overdue in \(.applicationName)",
                "Check for overdue bills in \(.applicationName)"
            ],
            shortTitle: "Overdue Bills",
            systemImageName: "exclamationmark.triangle"
        )
        
        AppShortcut(
            intent: GetBudgetStatusIntent(),
            phrases: [
                "What's my budget status in \(.applicationName)",
                "Budget status in \(.applicationName)",
                "How much of my budget have I used in \(.applicationName)"
            ],
            shortTitle: "Budget Status",
            systemImageName: "chart.bar"
        )
        
        AppShortcut(
            intent: SetBudgetIntent(),
            phrases: [
                "Set my monthly budget to in \(.applicationName)",
                "Change my budget in \(.applicationName)"
            ],
            shortTitle: "Set Budget",
            systemImageName: "dollarsign.circle.badge.plus"
        )
    }
}
