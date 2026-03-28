import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var billStore: BillStore
    @Binding var isPresented: Bool

    @State private var selectedPeriod: AnalyticsPeriod = .thisMonth
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Analytics")
                    .font(Theme.fontHeadline)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Picker("", selection: $selectedPeriod) {
                    ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Analytics period")
                .accessibilityHint("Select the time period for analytics data")
                .onChange(of: selectedPeriod) { _ in
                    viewModel.recompute(for: selectedPeriod, bills: billStore.bills)
                }

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(Theme.fontLabel)
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close analytics")
                .accessibilityHint("Closes the analytics view")
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
            .task(id: billStore.bills) {
                viewModel.recompute(for: selectedPeriod, bills: billStore.bills)
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
                value: formattedCurrency(viewModel.totalSpentInPeriod),
                icon: "dollarsign.circle",
                color: Theme.accent
            )
            summaryCard(
                title: "Bills Paid",
                value: "\(viewModel.billsPaidInPeriod.count)",
                icon: "checkmark.circle",
                color: Theme.success
            )
            summaryCard(
                title: "Avg per Bill",
                value: formattedCurrency(viewModel.averagePerBill),
                icon: "chart.bar",
                color: Theme.textSecondary
            )
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: Theme.spacing8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .accessibilityHidden(true)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Text(title)
                .font(Theme.fontCaption)
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
                .font(Theme.fontBodySemibold)
                .foregroundColor(Theme.textPrimary)

            VStack(spacing: Theme.spacing8) {
                ForEach(viewModel.sortedCategories, id: \.category) { item in
                    categoryBar(category: item.category, amount: item.amount, total: viewModel.totalSpentInPeriod)
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
                .accessibilityHidden(true)

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
                .font(Theme.fontBodySemibold)
                .foregroundColor(Theme.textPrimary)

            SimpleTrendChart(data: viewModel.monthlyTrendData)
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
                .font(Theme.fontBodySemibold)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: Theme.spacing8) {
                ForEach(viewModel.monthlyBreakdown, id: \.month) { item in
                    monthlyColumn(month: item.month, spent: item.spent, isCurrentMonth: item.isCurrentMonth, maxSpent: viewModel.monthlyMaxSpent)
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

    private func monthlyColumn(month: String, spent: Decimal, isCurrentMonth: Bool, maxSpent: Decimal) -> some View {
        let heightRatio = maxSpent > 0 ? NSDecimalNumber(decimal: spent / maxSpent).doubleValue : 0

        return VStack(spacing: 4) {
            Spacer()
            RoundedRectangle(cornerRadius: 3)
                .fill(isCurrentMonth ? Theme.accent : Theme.accent.opacity(0.4))
                .frame(height: max(4, 60 * heightRatio))
            Text(month)
                .font(.caption2)
                .foregroundColor(isCurrentMonth ? Theme.textPrimary : Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func formattedCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

// MARK: - Simple Trend Chart

struct SimpleTrendChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let data: [(month: String, amount: Decimal)]

    var body: some View {
        GeometryReader { geo in
            chartContent(geo: geo)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .animation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7), value: data.count)
    }

    private func chartContent(geo: GeometryProxy) -> some View {
        let maxAmount = data.map { $0.amount }.max() ?? 1
        let width = geo.size.width
        let height = geo.size.height - 20
        let stepX = width / CGFloat(max(data.count - 1, 1))

        return ZStack(alignment: .bottomLeading) {
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
                        .font(.caption2)
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

    private var accessibilityDescription: String {
        guard !data.isEmpty else { return "Spending trend chart with no data" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"

        var description = "Spending trend for \(data.count) months: "
        for point in data {
            let amountStr = formatter.string(from: NSDecimalNumber(decimal: point.amount)) ?? "$0"
            description += "\(point.month) \(amountStr), "
        }

        if let maxPoint = data.max(by: { $0.amount < $1.amount }),
           let maxAmount = formatter.string(from: NSDecimalNumber(decimal: maxPoint.amount)) {
            description += "Peak in \(maxPoint.month) at \(maxAmount)"
        }

        return description
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
