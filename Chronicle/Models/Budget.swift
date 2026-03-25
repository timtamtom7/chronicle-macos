import Foundation

// MARK: - Category Budget

struct CategoryBudget: Identifiable, Equatable, Codable {
    let id: UUID
    var category: Category
    var monthlyLimitCents: Int
    var isEnabled: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        category: Category,
        monthlyLimitCents: Int,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.monthlyLimitCents = monthlyLimitCents
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    var monthlyLimit: Decimal {
        Decimal(monthlyLimitCents) / 100
    }

    var formattedLimit: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: monthlyLimit)) ?? "$0.00"
    }
}

// MARK: - Budget Period

enum BudgetPeriod: String, CaseIterable, Codable {
    case currentMonth = "This Month"
    case lastMonth = "Last Month"
    case last3Months = "Last 3 Months"
    case last6Months = "Last 6 Months"
    case lastYear = "Last Year"
}

// MARK: - Budget Status

enum BudgetStatus {
    case underBudget
    case approachingBudget
    case atBudget
    case overBudget

    var color: String {
        switch self {
        case .underBudget: return "success"
        case .approachingBudget: return "warning"
        case .atBudget: return "accent"
        case .overBudget: return "danger"
        }
    }

    var icon: String {
        switch self {
        case .underBudget: return "checkmark.circle.fill"
        case .approachingBudget: return "exclamationmark.triangle.fill"
        case .atBudget: return "equal.circle.fill"
        case .overBudget: return "xmark.circle.fill"
        }
    }
}
