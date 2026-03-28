import Foundation

// MARK: - Currency

enum Currency: String, CaseIterable, Codable, Identifiable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case cad = "CAD"
    case aud = "AUD"
    case jpy = "JPY"
    case chf = "CHF"
    case inr = "INR"
    case brl = "BRL"
    case mxn = "MXN"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .cad: return "CA$"
        case .aud: return "A$"
        case .jpy: return "¥"
        case .chf: return "CHF"
        case .inr: return "₹"
        case .brl: return "R$"
        case .mxn: return "MX$"
        }
    }

    var name: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .cad: return "Canadian Dollar"
        case .aud: return "Australian Dollar"
        case .jpy: return "Japanese Yen"
        case .chf: return "Swiss Franc"
        case .inr: return "Indian Rupee"
        case .brl: return "Brazilian Real"
        case .mxn: return "Mexican Peso"
        }
    }

    var isZeroDecimal: Bool {
        switch self {
        case .jpy: return true
        default: return false
        }
    }
}

// MARK: - Bill Model

struct Bill: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var amountCents: Int
    var currency: Currency
    var dueDay: Int
    var dueDate: Date
    var recurrence: Recurrence
    var category: Category
    var notes: String?
    var reminderTimings: [ReminderTiming]
    var autoMarkPaid: Bool
    var isActive: Bool
    var isPaid: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amountCents: Int,
        currency: Currency = .usd,
        dueDay: Int,
        dueDate: Date,
        recurrence: Recurrence = .none,
        category: Category = .other,
        notes: String? = nil,
        reminderTimings: [ReminderTiming] = [],
        autoMarkPaid: Bool = false,
        isActive: Bool = true,
        isPaid: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.amountCents = amountCents
        self.currency = currency
        self.dueDay = dueDay
        self.dueDate = dueDate
        self.recurrence = recurrence
        self.category = category
        self.notes = notes
        self.reminderTimings = reminderTimings
        self.autoMarkPaid = autoMarkPaid
        self.isActive = isActive
        self.isPaid = isPaid
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

    func formattedAmountWithCode(_ showCode: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        let formatted = formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency.symbol)0.00"
        if showCode {
            return "\(formatted) \(currency.rawValue)"
        }
        return formatted
    }

    func amountInBaseCurrency(baseCurrency: Currency, rates: [String: Double]) -> Decimal? {
        if currency == baseCurrency { return amount }

        guard let rate = rates[currency.rawValue],
              let baseRate = rates[baseCurrency.rawValue],
              baseRate > 0 else { return nil }

        let rateToUSD = 1.0 / rate
        let amountUSD = NSDecimalNumber(decimal: amount).doubleValue * rateToUSD
        let targetRate = baseRate
        let amountInTarget = amountUSD * targetRate
        return Decimal(amountInTarget)
    }

    func formattedAmountInBaseCurrency(baseCurrency: Currency, rates: [String: Double]) -> String? {
        guard let converted = amountInBaseCurrency(baseCurrency: baseCurrency, rates: rates) else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = baseCurrency.rawValue
        return formatter.string(from: NSDecimalNumber(decimal: converted)) ?? "\(baseCurrency.symbol)0.00"
    }
}

// MARK: - Enums

enum Recurrence: String, CaseIterable, Codable {
    case none = "None"
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case semiAnnual = "Semi-annually"
    case annual = "Annually"

    var shortName: String {
        switch self {
        case .none: return "One-time"
        case .weekly: return "Weekly"
        case .biweekly: return "Biweekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .semiAnnual: return "Semi-ann."
        case .annual: return "Yearly"
        }
    }
}

enum Category: String, CaseIterable, Codable {
    case housing = "Housing"
    case utilities = "Utilities"
    case subscriptions = "Subscriptions"
    case insurance = "Insurance"
    case phoneInternet = "Phone/Internet"
    case transportation = "Transportation"
    case health = "Health"
    case other = "Other"

    var icon: String {
        switch self {
        case .housing: return "house.fill"
        case .utilities: return "bolt.fill"
        case .subscriptions: return "play.rectangle.fill"
        case .insurance: return "shield.fill"
        case .phoneInternet: return "globe"
        case .transportation: return "car.fill"
        case .health: return "heart.fill"
        case .other: return "tag.fill"
        }
    }
}

enum ReminderTiming: String, CaseIterable, Codable {
    case threeDays = "3 days before"
    case oneDay = "1 day before"
    case dueDate = "On due date"
    case none = "None"

    var daysOffset: Int {
        switch self {
        case .threeDays: return 3
        case .oneDay: return 1
        case .dueDate: return 0
        case .none: return -1
        }
    }
}

// MARK: - Due Date Status

enum BillStatus {
    case dueToday
    case dueSoon
    case upcoming
    case overdue
    case paid

    var borderColor: String {
        switch self {
        case .dueToday, .dueSoon: return "accent"
        case .upcoming: return "border"
        case .overdue: return "danger"
        case .paid: return "success"
        }
    }
}

extension Bill {
    func status(asOf date: Date = Date()) -> BillStatus {
        if isPaid { return .paid }

        let calendar = Calendar.current
        let dueStart = calendar.startOfDay(for: dueDate)
        let todayStart = calendar.startOfDay(for: date)

        if dueStart < todayStart {
            return .overdue
        } else if calendar.isDateInToday(dueDate) {
            return .dueToday
        } else if let threeDaysLater = calendar.date(byAdding: .day, value: 3, to: todayStart),
                  dueStart <= threeDaysLater {
            return .dueSoon
        } else {
            return .upcoming
        }
    }
}

// MARK: - Due Date Calculation

func calculateNextDueDate(bill: Bill, from date: Date = Date()) -> Date {
    let calendar = Calendar.current

    if bill.recurrence == .none {
        return bill.dueDate
    }

    var nextDate = bill.dueDate

    while nextDate <= date {
        switch bill.recurrence {
        case .none:
            return nextDate
        case .weekly:
            guard let next = calendar.date(byAdding: .day, value: 7, to: nextDate) else { return nextDate }
            nextDate = next
        case .biweekly:
            guard let next = calendar.date(byAdding: .day, value: 14, to: nextDate) else { return nextDate }
            nextDate = next
        case .monthly:
            nextDate = addMonth(to: nextDate, calendar: calendar)
        case .quarterly:
            guard let next = calendar.date(byAdding: .month, value: 3, to: nextDate) else { return nextDate }
            nextDate = next
        case .semiAnnual:
            guard let next = calendar.date(byAdding: .month, value: 6, to: nextDate) else { return nextDate }
            nextDate = next
        case .annual:
            guard let next = calendar.date(byAdding: .year, value: 1, to: nextDate) else { return nextDate }
            nextDate = next
        }
    }

    return nextDate
}

private func addMonth(to date: Date, calendar: Calendar) -> Date {
    guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else {
        return date
    }

    let originalDay = calendar.component(.day, from: date)
    let range = calendar.range(of: .day, in: .month, for: nextMonth)!
    let safeDay = min(originalDay, range.upperBound - 1)

    var components = calendar.dateComponents([.year, .month], from: nextMonth)
    components.day = safeDay

    return calendar.date(from: components) ?? nextMonth
}

// MARK: - Payment Record

struct PaymentRecord: Identifiable, Codable {
    let id: UUID
    let billId: UUID
    let amountPaidCents: Int
    let paidAt: Date

    init(id: UUID = UUID(), billId: UUID, amountPaidCents: Int, paidAt: Date = Date()) {
        self.id = id
        self.billId = billId
        self.amountPaidCents = amountPaidCents
        self.paidAt = paidAt
    }

    var amount: Decimal {
        Decimal(amountPaidCents) / 100
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}
