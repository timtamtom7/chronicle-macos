import Foundation
import SwiftUI
import Combine

/// View model that caches AnalyticsView computed properties.
/// Avoids O(bills × months) recomputation on every frame by
/// recalculating only when bills or selectedPeriod changes.
@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var billsInPeriod: [Bill] = []
    @Published var billsPaidInPeriod: [Bill] = []
    @Published var totalSpentInPeriod: Decimal = 0
    @Published var averagePerBill: Decimal = 0
    @Published var sortedCategories: [(category: Category, amount: Decimal)] = []
    @Published var monthlyTrendData: [(month: String, amount: Decimal)] = []
    @Published var monthlyBreakdown: [(month: String, spent: Decimal, isCurrentMonth: Bool)] = []
    @Published var monthlyMaxSpent: Decimal = 1

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    func recompute(for period: AnalyticsPeriod, bills: [Bill]) {
        let calendar = Calendar.current
        let now = Date()

        // 1. Filter bills in period
        switch period {
        case .thisMonth:
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
                clear()
                return
            }
            billsInPeriod = bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd }
        case .last3Months:
            guard let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) else {
                clear()
                return
            }
            billsInPeriod = bills.filter { $0.dueDate >= threeMonthsAgo }
        case .last6Months:
            guard let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) else {
                clear()
                return
            }
            billsInPeriod = bills.filter { $0.dueDate >= sixMonthsAgo }
        case .thisYear:
            guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) else {
                clear()
                return
            }
            billsInPeriod = bills.filter { $0.dueDate >= yearStart }
        }

        // 2. Paid bills in period
        billsPaidInPeriod = billsInPeriod.filter { $0.isPaid }

        // 3. Total spent
        totalSpentInPeriod = billsPaidInPeriod.reduce(Decimal(0)) { $0 + $1.amount }

        // 4. Average per bill
        averagePerBill = billsPaidInPeriod.isEmpty ? 0 : totalSpentInPeriod / Decimal(billsPaidInPeriod.count)

        // 5. Sorted categories
        var categoryTotals: [Category: Decimal] = [:]
        for bill in billsPaidInPeriod {
            categoryTotals[bill.category, default: 0] += bill.amount
        }
        sortedCategories = categoryTotals.map { ($0.key, $0.value) }.sorted { $0.amount > $1.amount }

        // 6. Monthly trend — single pass over 6 months
        var trendMap: [String: Decimal] = [:]
        for i in 0..<6 {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: now),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else { continue }
            let monthName = monthFormatter.string(from: monthStart)
            let spent = bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd && $0.isPaid }
                .reduce(Decimal(0)) { $0 + $1.amount }
            trendMap[monthName] = spent
        }
        monthlyTrendData = trendMap.map { (month: $0.key, amount: $0.value) }.sorted { lhs, rhs in
            let lhsDate = monthFormatter.date(from: lhs.month) ?? Date.distantPast
            let rhsDate = monthFormatter.date(from: rhs.month) ?? Date.distantPast
            return lhsDate < rhsDate
        }

        // 7. Monthly breakdown — single pass over 12 months
        let currentMonthNum = calendar.component(.month, from: now)
        var breakdown: [(String, Decimal, Bool)] = []
        for i in (0..<12).reversed() {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: now),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else { continue }
            let monthName = monthFormatter.string(from: monthStart)
            let monthNum = calendar.component(.month, from: monthStart)
            let spent = bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd && $0.isPaid }
                .reduce(Decimal(0)) { $0 + $1.amount }
            breakdown.append((monthName, spent, monthNum == currentMonthNum))
        }
        monthlyBreakdown = breakdown

        // 8. Precomputed max spent — avoids O(n) max() per column per render
        monthlyMaxSpent = monthlyBreakdown.map { $0.spent }.max() ?? 1
    }

    private func clear() {
        billsInPeriod = []
        billsPaidInPeriod = []
        totalSpentInPeriod = 0
        averagePerBill = 0
        sortedCategories = []
        monthlyTrendData = []
        monthlyBreakdown = []
        monthlyMaxSpent = 1
    }
}
