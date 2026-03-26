import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var billStore: BillStore
    @Binding var isPresented: Bool

    @State private var selectedPeriod: AnalyticsPeriod = .thisMonth

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Analytics")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Picker("", selection: $selectedPeriod) {
                    ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.menu)

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.spacing16)

            Divider()

            ScrollView {
                VStack(spacing: Theme.spacing16) {
                    // Summary Cards
                    summarySection

                    // Category Breakdown
                    categoryBreakdownSection

                    // Monthly Trend
                    monthlyTrendSection

                    // Yearly Overview
                    yearlyOverviewSection
                }
                .padding(Theme.spacing16)
            }
        }
        .frame(width: 520, height: 580)
        .background(Theme.background)
    }

    // MARK: - Summary

    private var summarySection: some View {
        HStack(spacing: Theme.spacing12) {
            summaryCard(
                title: "Total Spent",
                value: formattedCurrency(totalSpentInPeriod),
                icon: "dollarsign.circle",
                color: Theme.accent
            )
            summaryCard(
                title: "Bills Paid",
                value: "\(billsPaidInPeriod.count)",
                icon: "checkmark.circle",
                color: Theme.success
            )
            summaryCard(
                title: "Avg per Bill",
                value: formattedCurrency(averagePerBill),
                icon: "chart.bar",
                color: Theme.warning
            )
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: Theme.spacing8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text("Spending by Category")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            VStack(spacing: Theme.spacing8) {
                ForEach(sortedCategories, id: \.category) { item in
                    categoryBar(category: item.category, amount: item.amount, total: totalSpentInPeriod)
                }
            }
            .padding(Theme.spacing12)
            .background(Theme.surface)
            .cornerRadius(Theme.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    private func categoryBar(category: Category, amount: Decimal, total: Decimal) -> some View {
        let percentage = total > 0 ? NSDecimalNumber(decimal: amount / total).doubleValue : 0

        return HStack(spacing: Theme.spacing8) {
            Image(systemName: category.icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.accent)
                .frame(width: 16)

            Text(category.rawValue)
                .font(.system(size: 12))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.surfaceSecondary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.accent.opacity(0.6))
                        .frame(width: geo.size.width * percentage)
                }
            }
            .frame(height: 10)

            Text("\(Int(percentage * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 36, alignment: .trailing)

            Text(formattedCurrency(amount))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 60, alignment: .trailing)
        }
    }

    // MARK: - Monthly Trend

    private var monthlyTrendSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text("Monthly Trend")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            SimpleTrendChart(data: monthlyTrendData)
                .frame(height: 120)
                .padding(Theme.spacing12)
                .background(Theme.surface)
                .cornerRadius(Theme.radiusMedium)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Yearly Overview

    private var yearlyOverviewSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text("Yearly Overview")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: Theme.spacing8) {
                ForEach(monthlyBreakdown, id: \.month) { item in
                    monthlyColumn(month: item.month, spent: item.spent, isCurrentMonth: item.isCurrentMonth)
                }
            }
            .padding(Theme.spacing12)
            .background(Theme.surface)
            .cornerRadius(Theme.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    private func monthlyColumn(month: String, spent: Decimal, isCurrentMonth: Bool) -> some View {
        let maxSpent = monthlyBreakdown.map { $0.spent }.max() ?? 1
        let heightRatio = maxSpent > 0 ? NSDecimalNumber(decimal: spent / maxSpent).doubleValue : 0

        return VStack(spacing: 4) {
            Spacer()
            RoundedRectangle(cornerRadius: 3)
                .fill(isCurrentMonth ? Theme.accent : Theme.accent.opacity(0.4))
                .frame(height: max(4, 60 * heightRatio))
            Text(month)
                .font(.system(size: 9))
                .foregroundColor(isCurrentMonth ? Theme.textPrimary : Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed Data

    private var billsInPeriod: [Bill] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .thisMonth:
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
                return []
            }
            return billStore.bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd }
        case .last3Months:
            guard let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) else {
                return []
            }
            return billStore.bills.filter { $0.dueDate >= threeMonthsAgo }
        case .last6Months:
            guard let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) else {
                return []
            }
            return billStore.bills.filter { $0.dueDate >= sixMonthsAgo }
        case .thisYear:
            guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) else {
                return []
            }
            return billStore.bills.filter { $0.dueDate >= yearStart }
        }
    }

    private var billsPaidInPeriod: [Bill] {
        billsInPeriod.filter { $0.isPaid }
    }

    private var totalSpentInPeriod: Decimal {
        billsPaidInPeriod.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var averagePerBill: Decimal {
        guard !billsPaidInPeriod.isEmpty else { return 0 }
        return totalSpentInPeriod / Decimal(billsPaidInPeriod.count)
    }

    private var sortedCategories: [(category: Category, amount: Decimal)] {
        var result: [Category: Decimal] = [:]
        for bill in billsPaidInPeriod {
            result[bill.category, default: 0] += bill.amount
        }
        return result.map { ($0.key, $0.value) }.sorted { $0.amount > $1.amount }
    }

    private var monthlyTrendData: [(month: String, amount: Decimal)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [String: Decimal] = [:]
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"

        for i in 0..<6 {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: now),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else { continue }

            let monthName = monthFormatter.string(from: monthStart)
            let monthBills = billStore.bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd && $0.isPaid }
            result[monthName] = monthBills.reduce(Decimal(0)) { $0 + $1.amount }
        }

        return result.map { (month: $0.key, amount: $0.value) }.sorted { lhs, rhs in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let lhsDate = formatter.date(from: lhs.month) ?? Date()
            let rhsDate = formatter.date(from: rhs.month) ?? Date()
            return lhsDate < rhsDate
        }
    }

    private var monthlyBreakdown: [(month: String, spent: Decimal, isCurrentMonth: Bool)] {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        var result: [(String, Decimal, Bool)] = []
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"

        for i in (0..<12).reversed() {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: now),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else { continue }

            let monthName = monthFormatter.string(from: monthStart)
            let monthNum = calendar.component(.month, from: monthStart)
            let monthBills = billStore.bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd && $0.isPaid }
            let spent = monthBills.reduce(Decimal(0)) { $0 + $1.amount }
            result.append((monthName, spent, monthNum == currentMonth))
        }

        return result
    }

    private func formattedCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

// MARK: - Simple Trend Chart

struct SimpleTrendChart: View {
    let data: [(month: String, amount: Decimal)]

    var body: some View {
        GeometryReader { geo in
            let maxAmount = data.map { $0.amount }.max() ?? 1
            let width = geo.size.width
            let height = geo.size.height - 20
            let stepX = width / CGFloat(max(data.count - 1, 1))

            ZStack(alignment: .bottomLeading) {
                // Grid lines
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in
                        Divider()
                            .background(Theme.border.opacity(0.5))
                        if i < 3 {
                            Spacer()
                        }
                    }
                }
                .frame(height: height)

                // Line chart
                if data.count > 1 {
                    Path { path in
                        for (i, point) in data.enumerated() {
                            let x = stepX * CGFloat(i)
                            let ratio = NSDecimalNumber(decimal: point.amount / maxAmount).doubleValue
                            let y = height - (height * ratio)

                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Theme.accent, lineWidth: 2)

                    // Points
                    ForEach(Array(data.enumerated()), id: \.offset) { i, point in
                        let x = stepX * CGFloat(i)
                        let ratio = NSDecimalNumber(decimal: point.amount / maxAmount).doubleValue
                        let y = height - (height * ratio)

                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                    }
                }

                // Month labels
                HStack(spacing: 0) {
                    ForEach(Array(data.enumerated()), id: \.offset) { i, point in
                        Text(point.month)
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textTertiary)
                        if i < data.count - 1 {
                            Spacer()
                        }
                    }
                }
                .frame(width: width, height: 20)
                .offset(y: height + 2)
            }
        }
    }
}

// MARK: - Period

enum AnalyticsPeriod: String, CaseIterable {
    case thisMonth
    case last3Months
    case last6Months
    case thisYear

    var title: String {
        switch self {
        case .thisMonth: return "This Month"
        case .last3Months: return "3 Months"
        case .last6Months: return "6 Months"
        case .thisYear: return "This Year"
        }
    }
}
