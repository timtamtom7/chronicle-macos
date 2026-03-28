import SwiftUI

// MARK: - Household Dashboard View

struct HouseholdDashboardView: View {
    @EnvironmentObject var billStore: BillStore
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var householdService = HouseholdService.shared
    @State private var showCreateHousehold = false
    @State private var showJoinHousehold = false
    @State private var householdName = ""
    @State private var ownerName = ""
    @State private var inviteCode = ""
    @State private var showQRCode = false

    var body: some View {
        Group {
            if let household = householdService.household {
                householdContent(household)
            } else {
                noHouseholdView
            }
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

            HStack(spacing: 16) {
                Button("Create Household") {
                    showCreateHousehold = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Create household")
                .accessibilityHint("Create a new household to share bills with")

                Button("Join Household") {
                    showJoinHousehold = true
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Join household")
                .accessibilityHint("Join an existing household using an invite code")
            }
        }
        .padding()
        .sheet(isPresented: $showCreateHousehold) {
            createHouseholdSheet
        }
        .sheet(isPresented: $showJoinHousehold) {
            joinHouseholdSheet
        }
    }

    // MARK: - Household Content

    private func householdContent(_ household: Household) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(household.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text("\(household.members.count) members")
                            .font(.body)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    Menu {
                        Button("Invite Members") { showQRCode = true }
                        Button("Add Member") { }
                        Divider()
                        Button("Leave Household", role: .destructive) { }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                    }
                    .accessibilityLabel("Household options menu")
                }
                .padding()

                // Members
                membersSection(household.members)

                // Balances
                balancesSection

                // Bills This Month
                billsThisMonthSection
            }
        }
        .sheet(isPresented: $showQRCode) {
            qrCodeSheet(household)
        }
    }

    // MARK: - Members Section

    private func membersSection(_ members: [HouseholdMember]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members")
                .font(.body)
                .foregroundColor(Theme.textPrimary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                ForEach(members) { member in
                    memberCard(member)
                }
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    private func memberCard(_ member: HouseholdMember) -> some View {
        let avatarColor: Color = {
            if colorScheme == .dark, let darkHex = member.colorHexDark {
                return Color(hex: darkHex)
            }
            return Color(hex: member.colorHex)
        }()

        return VStack(spacing: 8) {
            Image(systemName: member.avatarName)
                .font(.system(size: 32))
                .foregroundColor(avatarColor)
                .accessibilityHidden(true)

            Text(member.name)
                .font(.footnote)
                .foregroundColor(Theme.textPrimary)

            if member.isOwner {
                Text("Owner")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.surfaceSecondary)
        .cornerRadius(Theme.radiusSmall)
        .accessibilityLabel("\(member.name)\(member.isOwner ? ", owner" : "")")
    }

    // MARK: - Balances Section

    private var balancesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Balances")
                .font(.body)
                .foregroundColor(Theme.textPrimary)

            if householdService.balances.isEmpty {
                Text("No outstanding balances")
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(householdService.balances) { balance in
                    balanceRow(balance)
                }
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    private func balanceRow(_ balance: MemberBalance) -> some View {
        HStack {
            Text(balance.memberName)
                .font(.body)
                .foregroundColor(Theme.textPrimary)

            Spacer()

            if balance.isOwed {
                Text("+\(formatCents(balance.netBalanceCents))")
                    .font(.footnote)
                    .foregroundColor(Theme.success)
            } else if balance.owes {
                Text("-\(formatCents(abs(balance.netBalanceCents)))")
                    .font(.footnote)
                    .foregroundColor(Theme.danger)
            } else {
                Text("Settled")
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(balance.memberName), \(balance.isOwed ? "is owed \(formatCents(balance.netBalanceCents))" : balance.owes ? "owes \(formatCents(abs(balance.netBalanceCents)))" : "settled")")
    }

    // MARK: - Bills This Month

    private var billsThisMonthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bills This Month")
                    .font(.body)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Text("\(getBillsThisMonth().count) bills")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            ForEach(getBillsThisMonth()) { bill in
                billRow(bill)
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    private func billRow(_ bill: Bill) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(bill.name)
                    .font(.footnote)
                    .foregroundColor(Theme.textPrimary)
                Text(bill.category.rawValue)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Text(bill.formattedAmount)
                .font(.footnote)
                .foregroundColor(Theme.textPrimary)

            Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                .font(.callout)
                .foregroundColor(bill.isPaid ? Theme.success : Theme.textTertiary)
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(bill.name), \(bill.formattedAmount), \(bill.isPaid ? "paid" : "unpaid")")
    }

    // MARK: - QR Code Sheet

    private func qrCodeSheet(_ household: Household) -> some View {
        VStack(spacing: 24) {
            Text("Invite to \(household.name)")
                .font(.title2)
                .foregroundColor(Theme.textPrimary)

            if let qrImage = householdService.generateInviteQRCode(for: household) {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .accessibilityLabel("QR code for household invite. Code is: \(household.inviteCode)")
            }

            Text("Invite Code: \(household.inviteCode)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textPrimary)

            Text("Scan this QR code or enter the invite code on another Mac to join this household.")
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: 300)

            Button("Done") {
                showQRCode = false
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Done")
            .accessibilityHint("Closes the QR code sheet")
        }
        .padding(32)
    }

    // MARK: - Create Household Sheet

    private var createHouseholdSheet: some View {
        VStack(spacing: 20) {
            Text("Create Household")
                .font(.title2)
                .foregroundColor(Theme.textPrimary)

            TextField("Household Name", text: $householdName)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Household name")

            TextField("Your Name", text: $ownerName)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Your name")

            HStack {
                Button("Cancel") {
                    showCreateHousehold = false
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Cancel")

                Button("Create") {
                    _ = householdService.createHousehold(name: householdName, ownerName: ownerName)
                    showCreateHousehold = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(householdName.isEmpty || ownerName.isEmpty)
                .accessibilityLabel("Create")
            }
        }
        .padding(32)
        .frame(width: 350)
    }

    // MARK: - Join Household Sheet

    private var joinHouseholdSheet: some View {
        VStack(spacing: 20) {
            Text("Join Household")
                .font(.title2)
                .foregroundColor(Theme.textPrimary)

            TextField("Invite Code", text: $inviteCode)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Invite code")

            HStack {
                Button("Cancel") {
                    showJoinHousehold = false
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Cancel")

                Button("Join") {
                    if householdService.joinHousehold(code: inviteCode) {
                        showJoinHousehold = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inviteCode.isEmpty)
                .accessibilityLabel("Join")
            }
        }
        .padding(32)
        .frame(width: 350)
    }

    // MARK: - Helpers

    private func getBillsThisMonth() -> [Bill] {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return []
        }

        return billStore.bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd }
    }

    private func formatCents(_ cents: Int) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}
