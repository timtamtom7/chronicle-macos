import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var billStore: BillStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searchText = ""
    @State private var groupedRecords: [YearMonth: [PaymentRecord]] = [:]
    @State private var selectedMonth: YearMonth?
    @State private var undoToast: UndoToastData?
    /// O(1) bill name lookup cache — built in loadData() to avoid O(n²) per-record search
    @State private var billNameCache: [UUID: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textTertiary)
                TextField("Search by bill name", text: $searchText)
                    .font(Theme.fontBody)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search payment history")
                    .accessibilityHint("Type to filter payment records by bill name")
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, Theme.spacing12)
            .padding(.vertical, Theme.spacing8)
            .background(Theme.surface)
            .cornerRadius(Theme.radiusSmall)

            if groupedRecords.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.spacing4, pinnedViews: [.sectionHeaders]) {
                        ForEach(sortedMonths, id: \.self) { month in
                            Section {
                                ForEach(filteredRecords(for: month)) { record in
                                    HistoryRowView(record: record, billName: billName(for: record))
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                undoPayment(record)
                                            } label: {
                                                Label("Undo Payment", systemImage: "arrow.uturn.backward")
                                            }
                                        }
                                }
                            } header: {
                                monthSectionHeader(month)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.spacing16)
                    .padding(.vertical, Theme.spacing8)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = undoToast {
                undoToastView(toast)
                    .padding(.bottom, Theme.spacing16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            loadData()
        }
        .onChange(of: billStore.bills) { _ in
            loadData()
        }
    }

    // MARK: - Data

    private func loadData() {
        groupedRecords = billStore.paymentRecordsGroupedByMonth()
        // Build O(1) lookup cache — avoids O(n) .first(where:) per record per render
        billNameCache = Dictionary(uniqueKeysWithValues: billStore.bills.map { ($0.id, $0.name) })
    }

    private var sortedMonths: [YearMonth] {
        groupedRecords.keys.sorted(by: >)
    }

    private func billName(for record: PaymentRecord) -> String {
        billNameCache[record.billId] ?? "Unknown Bill"
    }

    private func filteredRecords(for month: YearMonth) -> [PaymentRecord] {
        guard let records = groupedRecords[month] else { return [] }
        if searchText.isEmpty { return records }
        return records.filter { billName(for: $0).localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Month Section Header

    private func monthSectionHeader(_ month: YearMonth) -> some View {
        HStack {
            Text(month.displayString)
                .font(Theme.fontSubheadlineSemibold)
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text(monthTotal(for: month))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Theme.success)
        }
        .padding(.horizontal, Theme.spacing12)
        .padding(.vertical, Theme.spacing8)
        .background(Theme.background)
    }

    private func monthTotal(for month: YearMonth) -> String {
        guard let records = groupedRecords[month] else { return "$0.00" }
        let total = records.reduce(Decimal(0)) { $0 + $1.amount }
        return formatCurrency(total)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.spacing12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 36))
                .foregroundColor(Theme.textTertiary)

            Text("No payments recorded yet")
                .font(Theme.fontMediumLabel)
                .foregroundColor(Theme.textSecondary)

            Text("Mark a bill as paid to see it here")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, Theme.spacing32)
    }

    // MARK: - Undo

    private func undoPayment(_ record: PaymentRecord) {
        let billName = billName(for: record)
        billStore.undoPayment(record: record)
        loadData()

        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
            undoToast = UndoToastData(billName: billName)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                undoToast = nil
            }
        }
    }

    private func undoToastView(_ toast: UndoToastData) -> some View {
        HStack(spacing: Theme.spacing12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.success)
                .font(Theme.fontMediumLabel)

            Text("Payment for \(toast.billName) undone")
                .font(Theme.fontBody)
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .accessibilityLabel("Payment for \(toast.billName) has been undone")
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}

// MARK: - History Row View

struct HistoryRowView: View {
    let record: PaymentRecord
    let billName: String

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            // Bill name
            Text(billName)
                .font(Theme.fontMediumLabel)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .accessibilityLabel("\(billName), paid \(record.formattedAmount)")

            Spacer()

            // Amount
            Text(record.formattedAmount)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.success)

            // Date
            Text(formattedDate)
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, Theme.spacing12)
        .padding(.vertical, Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusSmall)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: record.paidAt)
    }
}

// MARK: - Undo Toast Data

struct UndoToastData: Equatable {
    let billName: String
}
