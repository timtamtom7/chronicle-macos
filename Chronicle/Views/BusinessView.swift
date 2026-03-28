import SwiftUI
import UniformTypeIdentifiers

// MARK: - Business View

struct BusinessView: View {
    @EnvironmentObject var billStore: BillStore
    @StateObject private var businessService = BusinessService.shared
    @State private var selectedTab = 0
    @State private var showTaxReportGenerator = false
    @State private var selectedYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("", selection: $selectedTab) {
                Text("Tax Categories").tag(0)
                Text("Reimbursable").tag(1)
                Text("Tax Report").tag(2)
                Text("Accountant Mode").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Content
            TabView(selection: $selectedTab) {
                taxCategoriesView.tag(0)
                reimbursableView.tag(1)
                taxReportView.tag(2)
                accountantModeView.tag(3)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Tax Categories View

    private var taxCategoriesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Business Expense Categories")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text("Tag bills as tax-deductible or business expenses to track for tax season.")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                    ForEach(BusinessCategory.allCases) { category in
                        categoryCard(category)
                    }
                }

                Divider()

                Text("Reimbursable Bills")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text("Bills marked as reimbursable will be tracked for expense reports.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)

                // Show bills with business info
                let bills = billStore.bills.filter { businessService.getBusinessInfo(for: $0.id) != nil }
                ForEach(bills) { bill in
                    if let info = businessService.getBusinessInfo(for: bill.id) {
                        businessBillRow(bill, info: info)
                    }
                }
            }
            .padding()
        }
    }

    private func categoryCard(_ category: BusinessCategory) -> some View {
        VStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 20))
                .foregroundColor(Theme.accent)
                .accessibilityHidden(true)

            Text(category.rawValue)
                .font(Theme.fontBody)
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.radiusSmall)
    }

    private func businessBillRow(_ bill: Bill, info: BusinessBillInfo) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(bill.name)
                    .font(Theme.fontLabel)
                    .foregroundColor(Theme.textPrimary)
                HStack(spacing: 8) {
                    if info.isTaxDeductible {
                        Label("Tax Deductible", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.success)
                    }
                    if info.isReimbursable {
                        Label("Reimbursable", systemImage: "dollarsign.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.accent)
                    }
                }
            }

            Spacer()

            Text(bill.formattedAmount)
                .font(Theme.fontLabel)
                .foregroundColor(Theme.textPrimary)

            Text(info.businessCategory.rawValue)
                .font(Theme.fontCaption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.accent.opacity(0.2))
                .cornerRadius(4)
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.radiusSmall)
    }

    // MARK: - Reimbursable View

    private var reimbursableView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Reimbursable Expenses")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text("Track expenses that need to be reimbursed by your employer or clients.")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)

                if businessService.reimbursableBills.isEmpty {
                    emptyReimbursableView
                } else {
                    ForEach(businessService.reimbursableBills) { bill in
                        reimbursableRow(bill)
                    }
                }
            }
            .padding()
        }
    }

    private var emptyReimbursableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Theme.textTertiary)
                .accessibilityHidden(true)
            Text("No Reimbursable Bills")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text("Mark bills as reimbursable from the bill detail view.")
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func reimbursableRow(_ reimbursable: ReimbursableBill) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Bill \(reimbursable.billId.uuidString.prefix(8))")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textPrimary)
                Text(reimbursable.status.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(statusColor(reimbursable.status))
            }

            Spacer()

            Text(formatCents(reimbursable.amountCents))
                .font(Theme.fontLabel)
                .foregroundColor(Theme.textPrimary)

            statusButton(reimbursable)
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.radiusSmall)
    }

    private func statusButton(_ reimbursable: ReimbursableBill) -> some View {
        Group {
            switch reimbursable.status {
            case .pending:
                Button("Submit") {
                    businessService.submitForReimbursement(reimbursable.id)
                }
                .buttonStyle(.borderedProminent)

            case .submitted:
                Button("Mark Reimbursed") {
                    businessService.markReimbursed(reimbursable.id)
                }
                .buttonStyle(.bordered)

            case .reimbursed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.success)

            case .rejected:
                Button("Retry") {
                    businessService.submitForReimbursement(reimbursable.id)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func statusColor(_ status: ReimbursementStatus) -> Color {
        switch status {
        case .pending: return Theme.warning
        case .submitted: return Theme.accent
        case .reimbursed: return Theme.success
        case .rejected: return Theme.danger
        }
    }

    // MARK: - Tax Report View

    private var taxReportView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Tax Preparation Report")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Picker("Year", selection: $selectedYear) {
                        ForEach((2020...2030).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .frame(width: 100)
                }

                Text("Generate a tax report for your accountant or bookkeeper.")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)

                Button("Generate Report") {
                    generateTaxReport()
                }
                .buttonStyle(.borderedProminent)

                if let report = getLastReport() {
                    reportSummary(report)
                }
            }
            .padding()
        }
    }

    private func reportSummary(_ report: TaxReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(report.year) Tax Summary")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            HStack {
                VStack {
                    Text("Total Deductible")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Text(formatDecimal(report.totalDeductible))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.success)
                }

                Spacer()

                VStack {
                    Text("Total Reimbursable")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Text(formatDecimal(report.totalReimbursable))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.accent)
                }
            }

            Divider()

            Text("By Category")
                .font(Theme.fontLabel)
                .foregroundColor(Theme.textPrimary)

            ForEach(Array(report.categories.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { category in
                HStack {
                    Text(category.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text(formatDecimal(report.categories[category] ?? 0))
                        .font(Theme.fontLabel)
                        .foregroundColor(Theme.textPrimary)
                }
            }

            HStack {
                Button("Export CSV") {
                    exportCSV(report)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.radiusSmall)
    }

    // MARK: - Accountant Mode View

    private var accountantModeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Accountant Mode")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text("Enable read-only mode with a locked date range for accountant access.")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)

                if businessService.accountantMode.isEnabled {
                    enabledAccountantMode
                } else {
                    disabledAccountantMode
                }
            }
            .padding()
        }
    }

    private var enabledAccountantMode: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(Theme.success)
                Text("Accountant Mode Active")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.success)
            }

            if let range = businessService.accountantMode.lockedDateRange {
                Text("Locked Period: \(formatDate(range.lowerBound)) - \(formatDate(range.upperBound))")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)
            }

            Text("Bills within the locked period cannot be edited.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)

            Button("Disable Accountant Mode") {
                businessService.disableAccountantMode()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Theme.success.opacity(0.1))
        .cornerRadius(Theme.radiusMedium)
    }

    private var disabledAccountantMode: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accountant Mode is currently disabled.")
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)

            DatePicker("Start Date", selection: .constant(Date()), displayedComponents: .date)
            DatePicker("End Date", selection: .constant(Date()), displayedComponents: .date)

            Button("Enable Accountant Mode") {
                // Would show date pickers and enable
                let now = Date()
                guard let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: now) else { return }
                businessService.enableAccountantMode(lockedRange: twoYearsAgo...now)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    // MARK: - Actions

    private func generateTaxReport() {
        let bills = billStore.bills
        _ = businessService.generateTaxReport(for: selectedYear, bills: bills)
    }

    private func getLastReport() -> TaxReport? {
        let bills = billStore.bills
        return businessService.generateTaxReport(for: selectedYear, bills: bills)
    }

    private func exportCSV(_ report: TaxReport) {
        let bills = billStore.bills
        if let url = businessService.exportTaxReportCSV(report, bills: bills) {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }

    // MARK: - Helpers

    private func formatCents(_ cents: Int) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }

    private func formatDecimal(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "$0.00"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
