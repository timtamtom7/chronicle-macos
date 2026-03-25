import SwiftUI

struct ContentView: View {
    @EnvironmentObject var billStore: BillStore
    var showMainWindow: () -> Void

    @State private var showingAddSheet = false
    @State private var selectedBill: Bill?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .padding(0)

            // Bill list
            ScrollView {
                VStack(spacing: Theme.spacing8) {
                    if billStore.upcomingBills.isEmpty {
                        emptyState
                    } else {
                        ForEach(billStore.upcomingBills.prefix(5)) { bill in
                            BillCardView(bill: bill, onTogglePaid: togglePaid)
                                .onTapGesture {
                                    selectedBill = bill
                                }
                        }

                        if billStore.upcomingBills.count > 5 {
                            Button(action: showMainWindow) {
                                HStack {
                                    Text("View All Bills")
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(Theme.accent)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, Theme.spacing8)
                        }
                    }
                }
                .padding(Theme.spacing16)
            }

            Divider()
                .padding(0)

            // Monthly overview footer
            monthlyOverview
        }
        .frame(width: 480, height: 400)
        .background(Theme.background)
        .sheet(isPresented: $showingAddSheet) {
            AddBillSheet(isPresented: $showingAddSheet)
        }
        .sheet(item: $selectedBill) { bill in
            AddBillSheet(isPresented: .constant(true), editingBill: bill)
                .environmentObject(billStore)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAddBillSheet)) { _ in
            showingAddSheet = true
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("Chronicle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Spacer()

            Button(action: { showingAddSheet = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundColor(Theme.accent)
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing12)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacing12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(Theme.textTertiary)

            Text("No upcoming bills")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            Text("Click + to add your first bill")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacing32)
    }

    private var monthlyOverview: some View {
        VStack(spacing: Theme.spacing8) {
            HStack {
                Text("Monthly Overview")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
                    .textCase(.uppercase)
                Spacer()
            }

            HStack(spacing: Theme.spacing16) {
                overviewItem(title: "Due", value: formatCurrency(billStore.totalDueThisMonth), color: Theme.accent)
                overviewItem(title: "Paid", value: formatCurrency(billStore.totalPaidThisMonth), color: Theme.success)
                overviewItem(title: "Remaining", value: formatCurrency(billStore.totalRemainingThisMonth), color: Theme.warning)
            }
        }
        .padding(Theme.spacing16)
        .background(Theme.surfaceSecondary)
    }

    private func overviewItem(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
        }
    }

    // MARK: - Helpers

    private func togglePaid(_ bill: Bill) {
        billStore.markPaid(bill, paid: !bill.isPaid)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}

// MARK: - Bill Card View (compact for popover)

struct BillCardView: View {
    let bill: Bill
    let onTogglePaid: (Bill) -> Void

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Category icon
            Image(systemName: bill.category.icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 20)

            // Name
            Text(bill.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Amount
            Text(bill.formattedAmount)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textPrimary)

            // Due date
            Text(formattedDueDate)
                .font(.system(size: 12))
                .foregroundColor(dueDateColor)
        }
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch bill.status() {
        case .dueToday, .dueSoon: return Theme.accent
        case .upcoming: return Theme.border
        case .overdue: return Theme.danger
        case .paid: return Theme.success
        }
    }

    private var dueDateColor: Color {
        switch bill.status() {
        case .dueToday: return Theme.accent
        case .overdue: return Theme.danger
        default: return Theme.textSecondary
        }
    }

    private var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Due \(formatter.string(from: bill.dueDate))"
    }
}
