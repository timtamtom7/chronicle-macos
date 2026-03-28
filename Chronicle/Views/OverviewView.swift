import SwiftUI
import Charts

struct OverviewView: View {
    @EnvironmentObject var billStore: BillStore
    @State private var selectedMonth: YearMonth = YearMonth(date: Date())

    var body: some View {
        VStack(spacing: 0) {
            // Month navigation header
            monthNavigator

            ScrollView {
                VStack(spacing: Theme.spacing16) {
                    // Summary cards
                    summaryCards

                    // Month progress bar
                    monthProgressBar

                    // Category breakdown
                    categoryBreakdown

                    // Spending trends
                    spendingTrends
                }
                .padding(Theme.spacing16)
            }
        }
        .onAppear {
            selectedMonth = YearMonth(date: Date())
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button(action: { selectedMonth = selectedMonth.previous() }) {
                Image(systemName: "chevron.left")
                    .font(Theme.fontLabel)
                    .foregroundColor(Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")
            .accessibilityHint("Navigate to the previous month")

            Spacer()

            Text(selectedMonth.displayString)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Spacer()

            Button(action: { selectedMonth = selectedMonth.next() }) {
                Image(systemName: "chevron.right")
                    .font(Theme.fontLabel)
                    .foregroundColor(canGoNext ? Theme.accent : Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!canGoNext)
            .accessibilityLabel("Next month")
            .accessibilityHint("Navigate to the next month")
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing12)
        .background(Theme.surfaceSecondary)
    }

    private var canGoNext: Bool {
        selectedMonth < YearMonth(date: Date())
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: Theme.spacing12) {
            summaryCard(
                title: "Total Due",
                value: formatCurrency(billStore.totalDueThisMonthValue()),
                color: Theme.accent,
                icon: "arrow.down.circle"
            )
            summaryCard(
                title: "Total Paid",
                value: formatCurrency(billStore.totalSpentThisMonth()),
                color: Theme.success,
                icon: "checkmark.circle"
            )
            summaryCard(
                title: "Remaining",
                value: formatCurrency(billStore.totalRemainingThisMonth),
                color: remainingColor,
                icon: "clock"
            )
        }
    }

    private func summaryCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                    .accessibilityHidden(true)
                Text(title)
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textTertiary)
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    private var remainingColor: Color {
        if billStore.totalRemainingThisMonth <= 0 {
            return Theme.success
        }
        let (_, _, status) = billStore.overallBudgetStatus
        switch status {
        case .overBudget: return Theme.danger
        case .atBudget, .approachingBudget: return Theme.warning
        case .underBudget: return Theme.textSecondary
        }
    }

    // MARK: - Month Progress Bar

    private var monthProgressBar: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            HStack {
                Text("Month Progress")
                    .font(Theme.fontSubheadlineSemibold)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                let pct = progressPercentage
                Text("\(Int(pct * 100))% paid")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.surfaceSecondary)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.success)
                        .frame(width: geo.size.width * progressPercentage, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    private var progressPercentage: CGFloat {
        let total = billStore.totalDueThisMonthValue()
        guard total > 0 else { return 1.0 }
        return CGFloat(truncating: (billStore.totalSpentThisMonth() / total) as NSDecimalNumber)
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            Text("Category Breakdown")
                .font(Theme.fontSubheadlineSemibold)
                .foregroundColor(Theme.textSecondary)

            let categoryData = billStore.spendingByCategory(for: selectedMonth)
            if categoryData.isEmpty {
                Text("No spending data for this month")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.spacing16)
            } else {
                let sortedCategories = categoryData.sorted { $0.value > $1.value }
                let maxAmount = sortedCategories.first?.value ?? 1

                ForEach(sortedCategories, id: \.key) { category, amount in
                    categoryBar(category: category, amount: amount, maxAmount: maxAmount)
                }
            }
        }
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    private func categoryBar(category: Category, amount: Decimal, maxAmount: Decimal) -> some View {
        let ratio = NSDecimalNumber(decimal: amount / maxAmount).doubleValue

        return HStack(spacing: Theme.spacing8) {
            Image(systemName: category.icon)
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textTertiary)
                .frame(width: 16)
                .accessibilityHidden(true)

            Text(category.rawValue)
                .font(.system(size: 12))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 100, alignment: .leading)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .fill(ThemeCategoryColors.map[category] ?? .gray)
                    .frame(width: geo.size.width * ratio, height: 16)
            }
            .frame(height: 16)

            Text(formatCurrency(amount))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 60, alignment: .trailing)
        }
    }

    // MARK: - Spending Trends

    private var spendingTrends: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            Text("Spending Trends")
                .font(Theme.fontSubheadlineSemibold)
                .foregroundColor(Theme.textSecondary)

            let trend = billStore.monthlyTrend(months: 6)
            if trend.isEmpty || trend.values.allSatisfy({ $0 == 0 }) {
                HStack {
                    Spacer()
                    VStack(spacing: Theme.spacing8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.textTertiary)
                        Text("Need more data")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, Theme.spacing16)
            } else {
                trendChart(data: trend)
            }
        }
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    @ViewBuilder
    private func trendChart(data: [YearMonth: Decimal]) -> some View {
        let sorted = data.keys.sorted()

        Chart {
            ForEach(sorted, id: \.self) { month in
                LineMark(
                    x: .value("Month", month.shortString),
                    y: .value("Spent", NSDecimalNumber(decimal: data[month] ?? 0).doubleValue)
                )
                .foregroundStyle(Theme.accent.gradient)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Month", month.shortString),
                    y: .value("Spent", NSDecimalNumber(decimal: data[month] ?? 0).doubleValue)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.3), Theme.accent.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(Theme.surfaceSecondary)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(formatShortCurrency(Decimal(v)))
                            .font(.caption2)
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }
        }
        .frame(height: 120)
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }

    private func formatShortCurrency(_ value: Decimal) -> String {
        let dollars = NSDecimalNumber(decimal: value).intValue
        if dollars >= 1000 {
            return "$\(dollars / 1000)k"
        }
        return "$\(dollars)"
    }
}
