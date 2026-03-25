import Foundation

final class BudgetService {
    static let shared = BudgetService()
    private let userDefaults = UserDefaults.standard
    private let budgetsKey = "categoryBudgets"
    private let monthlyBudgetKey = "monthlyBudgetCents"

    private init() {}

    // MARK: - Category Budgets

    func fetchAllBudgets() -> [CategoryBudget] {
        guard let data = userDefaults.data(forKey: budgetsKey) else { return [] }
        do {
            return try JSONDecoder().decode([CategoryBudget].self, from: data)
        } catch {
            print("Failed to decode budgets: \(error)")
            return []
        }
    }

    func saveBudget(_ budget: CategoryBudget) {
        var budgets = fetchAllBudgets()
        if let index = budgets.firstIndex(where: { $0.id == budget.id }) {
            budgets[index] = budget
        } else {
            budgets.append(budget)
        }
        saveBudgets(budgets)
    }

    func deleteBudget(_ budgetId: UUID) {
        var budgets = fetchAllBudgets()
        budgets.removeAll { $0.id == budgetId }
        saveBudgets(budgets)
    }

    func budget(for category: Category) -> CategoryBudget? {
        fetchAllBudgets().first { $0.category == category }
    }

    private func saveBudgets(_ budgets: [CategoryBudget]) {
        do {
            let data = try JSONEncoder().encode(budgets)
            userDefaults.set(data, forKey: budgetsKey)
        } catch {
            print("Failed to encode budgets: \(error)")
        }
    }

    // MARK: - Monthly Budget

    var monthlyBudgetCents: Int {
        get { userDefaults.integer(forKey: monthlyBudgetKey) }
        set { userDefaults.set(newValue, forKey: monthlyBudgetKey) }
    }

    var hasMonthlyBudget: Bool {
        monthlyBudgetCents > 0
    }

    var monthlyBudget: Decimal {
        Decimal(monthlyBudgetCents) / 100
    }

    var formattedMonthlyBudget: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: monthlyBudget)) ?? "$0.00"
    }

    // MARK: - Budget Status

    func budgetStatus(for budget: CategoryBudget, spent: Decimal) -> BudgetStatus {
        let limit = budget.monthlyLimit
        let ratio = spent / limit

        if ratio >= 1.0 {
            return .overBudget
        } else if ratio >= 0.9 {
            return .approachingBudget
        } else if ratio >= 0.75 {
            return .atBudget
        } else {
            return .underBudget
        }
    }

    func overallBudgetStatus(spent: Decimal, limit: Decimal) -> BudgetStatus {
        let ratio = spent / limit

        if ratio >= 1.0 {
            return .overBudget
        } else if ratio >= 0.9 {
            return .approachingBudget
        } else if ratio >= 0.75 {
            return .atBudget
        } else {
            return .underBudget
        }
    }
}
