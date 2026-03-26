import SwiftUI
import UniformTypeIdentifiers

// MARK: - Business View

struct BusinessView: View {
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
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Tag bills as tax-deductible or business expenses to track for tax season.")
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                    ForEach(BusinessCategory.allCases) { category in
                        categoryCard(category)
                    }
                }

                Divider()

                Text("Reimbursable Bills")
                    .font(.headline)

                Text("Bills marked as reimbursable will be tracked for expense reports.")
                    .foregroundColor(.secondary)
                    .font(.caption)

                // Show bills with business info
                let bills = BillStore().bills.filter { businessService.getBusinessInfo(for: $0.id) != nil }
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
                .font(.title)
                .foregroundColor(.accentColor)

            Text(category.rawValue)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func businessBillRow(_ bill: Bill, info: BusinessBillInfo) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(bill.name)
                    .font(.subheadline)
                HStack(spacing: 8) {
                    if info.isTaxDeductible {
                        Label("Tax Deductible", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if info.isReimbursable {
                        Label("Reimbursable", systemImage: "dollarsign.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Text(bill.formattedAmount)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(info.businessCategory.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.2))
                .cornerRadius(4)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Reimbursable View

    private var reimbursableView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Reimbursable Expenses")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Track expenses that need to be reimbursed by your employer or clients.")
                    .foregroundColor(.secondary)

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
                .foregroundColor(.secondary)
            Text("No Reimbursable Bills")
                .font(.headline)
            Text("Mark bills as reimbursable from the bill detail view.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func reimbursableRow(_ reimbursable: ReimbursableBill) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Bill \(reimbursable.billId.uuidString.prefix(8))")
                    .font(.subheadline)
                Text(reimbursable.status.rawValue)
                    .font(.caption)
                    .foregroundColor(statusColor(reimbursable.status))
            }

            Spacer()

            Text(formatCents(reimbursable.amountCents))
                .font(.subheadline)
                .fontWeight(.medium)

            statusButton(reimbursable)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
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
                    .foregroundColor(.green)

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
        case .pending: return .orange
        case .submitted: return .blue
        case .reimbursed: return .green
        case .rejected: return .red
        }
    }

    // MARK: - Tax Report View

    private var taxReportView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Tax Preparation Report")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Picker("Year", selection: $selectedYear) {
                        ForEach((2020...2030).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .frame(width: 100)
                }

                Text("Generate a tax report for your accountant or bookkeeper.")
                    .foregroundColor(.secondary)

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
                .font(.headline)

            HStack {
                VStack {
                    Text("Total Deductible")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDecimal(report.totalDeductible))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }

                Spacer()

                VStack {
                    Text("Total Reimbursable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDecimal(report.totalReimbursable))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }

            Divider()

            Text("By Category")
                .font(.subheadline)
                .fontWeight(.medium)

            ForEach(Array(report.categories.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { category in
                HStack {
                    Text(category.rawValue)
                    Spacer()
                    Text(formatDecimal(report.categories[category] ?? 0))
                        .fontWeight(.medium)
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
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Accountant Mode View

    private var accountantModeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Accountant Mode")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enable read-only mode with a locked date range for accountant access.")
                    .foregroundColor(.secondary)

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
                    .foregroundColor(.green)
                Text("Accountant Mode Active")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            if let range = businessService.accountantMode.lockedDateRange {
                Text("Locked Period: \(formatDate(range.lowerBound)) - \(formatDate(range.upperBound))")
                    .foregroundColor(.secondary)
            }

            Text("Bills within the locked period cannot be edited.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Disable Accountant Mode") {
                businessService.disableAccountantMode()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }

    private var disabledAccountantMode: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accountant Mode is currently disabled.")
                .foregroundColor(.secondary)

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
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func generateTaxReport() {
        let bills = BillStore().bills
        _ = businessService.generateTaxReport(for: selectedYear, bills: bills)
    }

    private func getLastReport() -> TaxReport? {
        let bills = BillStore().bills
        return businessService.generateTaxReport(for: selectedYear, bills: bills)
    }

    private func exportCSV(_ report: TaxReport) {
        let bills = BillStore().bills
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
