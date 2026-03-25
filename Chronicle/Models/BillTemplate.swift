import Foundation

// MARK: - Bill Template

struct BillTemplate: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var amountCents: Int
    var currency: Currency
    var dueDay: Int
    var recurrence: Recurrence
    var category: Category
    var notes: String?
    var reminderTimings: [ReminderTiming]
    var autoMarkPaid: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amountCents: Int,
        currency: Currency = .usd,
        dueDay: Int,
        recurrence: Recurrence = .none,
        category: Category = .other,
        notes: String? = nil,
        reminderTimings: [ReminderTiming] = [],
        autoMarkPaid: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.amountCents = amountCents
        self.currency = currency
        self.dueDay = dueDay
        self.recurrence = recurrence
        self.category = category
        self.notes = notes
        self.reminderTimings = reminderTimings
        self.autoMarkPaid = autoMarkPaid
        self.createdAt = createdAt
    }

    var amount: Decimal {
        Decimal(amountCents) / (currency.isZeroDecimal ? Decimal(1) : Decimal(100))
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency.symbol)0.00"
    }

    func toBill(dueDate: Date = Date()) -> Bill {
        Bill(
            id: UUID(),
            name: name,
            amountCents: amountCents,
            currency: currency,
            dueDay: dueDay,
            dueDate: dueDate,
            recurrence: recurrence,
            category: category,
            notes: notes,
            reminderTimings: reminderTimings,
            autoMarkPaid: autoMarkPaid,
            isActive: true,
            isPaid: false,
            createdAt: Date()
        )
    }

    static func fromBill(_ bill: Bill) -> BillTemplate {
        BillTemplate(
            id: UUID(),
            name: bill.name,
            amountCents: bill.amountCents,
            currency: bill.currency,
            dueDay: bill.dueDay,
            recurrence: bill.recurrence,
            category: bill.category,
            notes: bill.notes,
            reminderTimings: bill.reminderTimings,
            autoMarkPaid: bill.autoMarkPaid,
            createdAt: Date()
        )
    }
}
