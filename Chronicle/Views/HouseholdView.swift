import SwiftUI

// MARK: - Household Dashboard View

struct HouseholdDashboardView: View {
    @StateObject private var householdService = HouseholdService.shared
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
                .foregroundColor(.secondary)

            Text("Household Sharing")
                .font(.title)
                .fontWeight(.bold)

            Text("Share bills with your household, split expenses with roommates, and track who owes whom.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)

            HStack(spacing: 16) {
                Button("Create Household") {
                    showCreateHousehold = true
                }
                .buttonStyle(.borderedProminent)

                Button("Join Household") {
                    showJoinHousehold = true
                }
                .buttonStyle(.bordered)
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
                            .font(.title)
                            .fontWeight(.bold)
                        Text("\(household.members.count) members")
                            .foregroundColor(.secondary)
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
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                ForEach(members) { member in
                    memberCard(member)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func memberCard(_ member: HouseholdMember) -> some View {
        VStack(spacing: 8) {
            Image(systemName: member.avatarName)
                .font(.system(size: 32))
                .foregroundColor(Color(hex: member.colorHex))

            Text(member.name)
                .font(.subheadline)
                .fontWeight(.medium)

            if member.isOwner {
                Text("Owner")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Balances Section

    private var balancesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Balances")
                .font(.headline)

            if householdService.balances.isEmpty {
                Text("No outstanding balances")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(householdService.balances) { balance in
                    balanceRow(balance)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func balanceRow(_ balance: MemberBalance) -> some View {
        HStack {
            Text(balance.memberName)

            Spacer()

            if balance.isOwed {
                Text("+\(formatCents(balance.netBalanceCents))")
                    .foregroundColor(.green)
            } else if balance.owes {
                Text("-\(formatCents(abs(balance.netBalanceCents)))")
                    .foregroundColor(.red)
            } else {
                Text("Settled")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Bills This Month

    private var billsThisMonthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bills This Month")
                    .font(.headline)

                Spacer()

                Text("\(getBillsThisMonth().count) bills")
                    .foregroundColor(.secondary)
            }

            ForEach(getBillsThisMonth()) { bill in
                billRow(bill)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func billRow(_ bill: Bill) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(bill.name)
                    .font(.subheadline)
                Text(bill.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(bill.formattedAmount)
                .font(.subheadline)
                .fontWeight(.medium)

            Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(bill.isPaid ? .green : .secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - QR Code Sheet

    private func qrCodeSheet(_ household: Household) -> some View {
        VStack(spacing: 24) {
            Text("Invite to \(household.name)")
                .font(.title2)
                .fontWeight(.bold)

            if let qrImage = householdService.generateInviteQRCode(for: household) {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 200, height: 200)
            }

            Text("Invite Code: \(household.inviteCode)")
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)

            Text("Scan this QR code or enter the invite code on another Mac to join this household.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 300)

            Button("Done") {
                showQRCode = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    // MARK: - Create Household Sheet

    private var createHouseholdSheet: some View {
        VStack(spacing: 20) {
            Text("Create Household")
                .font(.title2)
                .fontWeight(.bold)

            TextField("Household Name", text: $householdName)
                .textFieldStyle(.roundedBorder)

            TextField("Your Name", text: $ownerName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    showCreateHousehold = false
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    _ = householdService.createHousehold(name: householdName, ownerName: ownerName)
                    showCreateHousehold = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(householdName.isEmpty || ownerName.isEmpty)
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
                .fontWeight(.bold)

            TextField("Invite Code", text: $inviteCode)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    showJoinHousehold = false
                }
                .buttonStyle(.bordered)

                Button("Join") {
                    if householdService.joinHousehold(code: inviteCode) {
                        showJoinHousehold = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inviteCode.isEmpty)
            }
        }
        .padding(32)
        .frame(width: 350)
    }

    // MARK: - Helpers

    private func getBillsThisMonth() -> [Bill] {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!

        return BillStore().bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd }
    }

    private func formatCents(_ cents: Int) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}
