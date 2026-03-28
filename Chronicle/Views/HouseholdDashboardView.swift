import SwiftUI
import AppKit

// MARK: - Household Dashboard View

struct HouseholdDashboardView: View {
    @EnvironmentObject var billStore: BillStore
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var householdService = HouseholdService.shared
    @State private var showInviteSheet = false
    @State private var selectedFilter: BillFilterOption = .all
    @State private var householdBillsThisMonth: [HouseholdBill] = []
    @State private var lastMonthTotal: Int = 0
    @State private var thisMonthTotal: Int = 0

    enum BillFilterOption: String, CaseIterable {
        case all = "All bills"
        case unpaid = "Unpaid only"
        case settleUp = "Settle up"
    }

    var body: some View {
        Group {
            if let household = householdService.household {
                dashboardContent(household)
            } else {
                noHouseholdView
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            if let household = householdService.household {
                InviteSheet(household: household)
            }
        }
        .onAppear {
            calculateBills()
        }
        .onChange(of: billStore.bills) { _ in
            calculateBills()
        }
    }

    // MARK: - No Household View

    private var noHouseholdView: some View {
        VStack(spacing: 24) {
            Image(systemName: "house.fill")
                .font(.system(size: 64))
                .foregroundColor(Theme.textTertiary)
                .accessibilityHidden(true)

            Text("Household Sharing")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("Share bills with your household, split expenses with roommates, and track who owes whom.")
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: 400)

            Button("Create or Join Household") {
                NotificationCenter.default.post(name: .openHouseholdSettings, object: nil)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Create or join household")
        }
        .padding()
    }

    // MARK: - Dashboard Content

    private func dashboardContent(_ household: Household) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                headerView(household)
                headerStatsView(household)
                filterToggleView
                membersGridView(household)
                billsListView
                balancesView
            }
            .padding(20)
        }
        .frame(minWidth: 560, minHeight: 400)
        .background(Theme.background)
    }

    // MARK: - Header

    private func headerView(_ household: Household) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(household.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(household.members.count) members")
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(syncStatusColor)
                    .frame(width: 8, height: 8)
                Text(syncStatusText)
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
            }

            Menu {
                Button("Invite Members", action: { showInviteSheet = true })
                Divider()
                Button("Leave Household", role: .destructive) {
                    householdService.leaveHousehold()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                    Text("Options")
                        .font(.caption)
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.surfaceSecondary)
                .cornerRadius(Theme.radiusSmall)
            }
            .accessibilityLabel("Household options menu")
        }
    }

    private var syncStatusColor: Color {
        switch householdService.syncStatus {
        case .idle: return Theme.textTertiary
        case .syncing: return Theme.accent
        case .error: return Theme.danger
        }
    }

    private var syncStatusText: String {
        switch householdService.syncStatus {
        case .idle: return "Synced"
        case .syncing: return "Syncing..."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    // MARK: - Header Stats

    private func headerStatsView(_ household: Household) -> some View {
        HStack(spacing: 16) {
            statCard(
                title: "This Month",
                value: formatCents(thisMonthTotal),
                subtitle: "\(householdBillsThisMonth.count) bills",
                color: Theme.accent
            )

            let diff = thisMonthTotal - lastMonthTotal
            statCard(
                title: "vs Last Month",
                value: diff >= 0 ? "+\(formatCents(diff))" : formatCents(diff),
                subtitle: diff >= 0 ? "more" : "less",
                color: diff <= 0 ? Theme.success : Theme.danger
            )

            let paidShares = householdBillsThisMonth.filter { bill in
                bill.split?.isFullyPaid ?? false
            }.count
            let totalShares = householdBillsThisMonth.count
            statCard(
                title: "Paid Status",
                value: "\(paidShares)/\(totalShares)",
                subtitle: "bills settled",
                color: paidShares == totalShares ? Theme.success : Theme.warning
            )
        }
    }

    private func statCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    // MARK: - Filter Toggle

    private var filterToggleView: some View {
        HStack(spacing: 0) {
            ForEach(BillFilterOption.allCases, id: \.self) { option in
                Button(action: { selectedFilter = option }) {
                    Text(option.rawValue)
                        .font(.caption)
                        .fontWeight(selectedFilter == option ? .semibold : .regular)
                        .foregroundColor(selectedFilter == option ? Theme.textOnAccent : Theme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedFilter == option ? Theme.accent : Color.clear)
                        .cornerRadius(Theme.radiusSmall)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(4)
        .background(Theme.surfaceSecondary)
        .cornerRadius(Theme.radiusMedium)
    }

    // MARK: - Members Grid

    private func membersGridView(_ household: Household) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MEMBERS")
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
                .tracking(Theme.trackingWide)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                ForEach(household.members) { member in
                    memberCard(member, household: household)
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    private func memberCard(_ member: HouseholdMember, household: Household) -> some View {
        let avatarColor: Color = {
            if colorScheme == .dark, let darkHex = member.colorHexDark {
                return Color(hex: darkHex)
            }
            return Color(hex: member.colorHex)
        }()

        let paidShares = householdBillsThisMonth.filter { bill in
            guard let split = bill.split else { return false }
            return split.splits.contains { $0.memberId == member.id && $0.isPaid }
        }.count
        let totalShares = householdBillsThisMonth.filter { bill in
            guard let split = bill.split else { return false }
            return split.splits.contains { $0.memberId == member.id }
        }.count

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: member.avatarName)
                    .font(.system(size: 24))
                    .foregroundColor(avatarColor)
            }
            .accessibilityHidden(true)

            Text(member.name)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)

            if member.isOwner {
                Text("Owner")
                    .font(.caption2)
                    .foregroundColor(Theme.textTertiary)
            } else {
                Text("\(paidShares)/\(totalShares) paid")
                    .font(.caption2)
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surfaceSecondary)
        .cornerRadius(Theme.radiusMedium)
        .accessibilityLabel("\(member.name), \(paidShares) of \(totalShares) shares paid")
    }

    // MARK: - Bills List

    @ViewBuilder
    private var billsListView: some View {
        let filteredBills = filteredBillsList

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedFilter == .settleUp ? "SETTLE UP" : "BILLS THIS MONTH")
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
                    .tracking(Theme.trackingWide)

                Spacer()

                Text("\(filteredBills.count) bills")
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
            }

            if filteredBills.isEmpty {
                emptyBillsView
            } else {
                ForEach(filteredBills) { householdBill in
                    householdBillRow(householdBill)
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    private var filteredBillsList: [HouseholdBill] {
        switch selectedFilter {
        case .all:
            return householdBillsThisMonth
        case .unpaid:
            return householdBillsThisMonth.filter { !($0.split?.isFullyPaid ?? false) }
        case .settleUp:
            return householdBillsThisMonth.filter { !($0.split?.isSettled ?? false) }
        }
    }

    private var emptyBillsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(Theme.success)
            Text(selectedFilter == .unpaid ? "All bills are paid!" : "No bills this month")
                .font(.body)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func householdBillRow(_ householdBill: HouseholdBill) -> some View {
        let bill = householdBill.bill
        let owner = householdService.household?.members.first { $0.id == householdBill.ownerId }

        return HStack(spacing: 12) {
            let isFullyPaid = householdBill.split?.isFullyPaid ?? false
            Image(systemName: isFullyPaid ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(isFullyPaid ? Theme.success : Theme.textTertiary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let owner = owner {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: owner.colorHex))
                                .frame(width: 6, height: 6)
                            Text("Paid by \(owner.name)")
                                .font(.caption)
                                .foregroundColor(Theme.textTertiary)
                        }
                    }

                    if let split = householdBill.split {
                        Text("·")
                            .foregroundColor(Theme.textTertiary)
                        Text("\(split.splits.count) way split")
                            .font(.caption)
                            .foregroundColor(Theme.textTertiary)
                    }
                }

                Text(bill.name)
                    .font(.callout)
                    .foregroundColor(Theme.textPrimary)
            }

            Spacer()

            Text(bill.formattedAmount)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)

            Image(systemName: bill.category.icon)
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Theme.surfaceSecondary)
        .cornerRadius(Theme.radiusSmall)
        .accessibilityLabel("\(bill.name), \(bill.formattedAmount), \(bill.isPaid ? "paid" : "unpaid")")
    }

    // MARK: - Balances

    private var balancesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHO OWES WHOM")
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
                .tracking(Theme.trackingWide)

            if householdService.balances.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.success)
                        Text("All settled up!")
                            .font(.body)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(householdService.balances) { balance in
                    balanceRow(balance)
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    private func balanceRow(_ balance: MemberBalance) -> some View {
        HStack {
            Text(balance.memberName)
                .font(.callout)
                .foregroundColor(Theme.textPrimary)

            Spacer()

            if balance.isOwed {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                    Text("+\(formatCents(balance.netBalanceCents))")
                }
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(Theme.success)
            } else if balance.owes {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                    Text("-\(formatCents(abs(balance.netBalanceCents)))")
                }
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(Theme.danger)
            } else {
                Text("Settled")
                    .font(.callout)
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Theme.surfaceSecondary)
        .cornerRadius(Theme.radiusSmall)
        .accessibilityLabel("\(balance.memberName), \(balance.isOwed ? "is owed \(formatCents(balance.netBalanceCents))" : balance.owes ? "owes \(formatCents(abs(balance.netBalanceCents)))" : "settled")")
    }

    // MARK: - Helpers

    private func calculateBills() {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart),
              let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart),
              let lastMonthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: lastMonthStart) else {
            return
        }

        guard let household = householdService.household else { return }

        householdBillsThisMonth = billStore.bills
            .filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd }
            .map { bill in
                HouseholdBill(
                    bill: bill,
                    ownerId: household.members.first?.id ?? HouseholdMember.currentUserId,
                    split: householdService.getSplit(for: bill.id),
                    householdId: household.id
                )
            }

        thisMonthTotal = householdBillsThisMonth.reduce(0) { $0 + $1.bill.amountCents }

        lastMonthTotal = billStore.bills
            .filter { $0.dueDate >= lastMonthStart && $0.dueDate <= lastMonthEnd }
            .reduce(0) { $0 + $1.amountCents }

        householdService.balances = householdService.calculateBalances(bills: householdBillsThisMonth)
    }

    private func formatCents(_ cents: Int) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openHouseholdSettings = Notification.Name("openHouseholdSettings")
}
