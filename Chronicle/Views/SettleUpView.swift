import SwiftUI

// MARK: - Settle Up View

/// Shows running balances and simplified debts for the household.
struct SettleUpView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var splitService = SplitBillService.shared
    @ObservedObject private var householdService = HouseholdService.shared

    @State private var showSettleConfirm = false
    @State private var settleNote = ""

    private var balances: [UUID: Decimal] {
        splitService.getRunningBalance()
    }

    private var debts: [(from: UUID, to: UUID, amount: Decimal)] {
        splitService.getOwesAmounts()
    }

    private var isAllSettled: Bool {
        debts.isEmpty && balances.values.allSatisfy { $0 == 0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settle Up")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                if isAllSettled {
                    Label("All settled", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(Theme.success)
                }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: Theme.spacing20) {
                    // Running Balances
                    balancesSection

                    Divider()

                    // Simplified Debts
                    debtsSection
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                if !isAllSettled {
                    Button("Settle All") {
                        showSettleConfirm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Settle all balances")
                    .accessibilityHint("Creates settlement records to zero out all member balances")
                }
                Spacer()
            }
            .padding()
        }
        .frame(width: 420, height: 500)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
        .alert("Settle All Balances?", isPresented: $showSettleConfirm) {
            TextField("Note (optional)", text: $settleNote)
                .accessibilityLabel("Settlement note")
            Button("Cancel", role: .cancel) {
                settleNote = ""
            }
            Button("Settle") {
                splitService.settleAllBalances()
                settleNote = ""
            }
        } message: {
            Text("This will record \(debts.count) payment\(debts.count == 1 ? "" : "s") to settle all outstanding balances.")
        }
    }

    // MARK: - Balances Section

    private var balancesSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            Text("Running Balances")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)

            if let household = householdService.household {
                ForEach(household.members) { member in
                    balanceRow(member: member)
                }
            }
        }
    }

    private func balanceRow(member: HouseholdMember) -> some View {
        let balance = balances[member.id] ?? 0
        let avatarColor: Color = {
            if colorScheme == .dark, let darkHex = member.colorHexDark {
                return Color(hex: darkHex)
            }
            return Color(hex: member.colorHex)
        }()

        return HStack(spacing: Theme.spacing12) {
            Image(systemName: member.avatarName)
                .font(.title3)
                .foregroundColor(avatarColor)
                .accessibilityHidden(true)

            Text(member.name)
                .font(.body)
                .foregroundColor(Theme.textPrimary)

            Spacer()

            if balance > 0 {
                Text("+\(formatDecimal(balance))")
                    .font(.body)
                    .foregroundColor(Theme.success)
            } else if balance < 0 {
                Text(formatDecimal(balance))
                    .font(.body)
                    .foregroundColor(Theme.danger)
            } else {
                Text("Settled")
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(member.name), \(balance > 0 ? "is owed \(formatDecimal(balance))" : balance < 0 ? "owes \(formatDecimal(abs(balance)))" : "settled")")
    }

    // MARK: - Debts Section

    private var debtsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack {
                Text("Simplified Debts")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                Text("\(debts.count) payment\(debts.count == 1 ? "" : "s") to settle")
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
            }

            if debts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.largeTitle)
                            .foregroundColor(Theme.success)
                        Text("Everyone is settled up!")
                            .font(.body)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, Theme.spacing16)
                    Spacer()
                }
            } else {
                ForEach(Array(debts.enumerated()), id: \.offset) { _, debt in
                    debtRow(debt)
                }
            }
        }
    }

    private func debtRow(_ debt: (from: UUID, to: UUID, amount: Decimal)) -> some View {
        let fromMember = householdService.household?.members.first { $0.id == debt.from }
        let toMember = householdService.household?.members.first { $0.id == debt.to }

        let fromColor: Color = {
            if colorScheme == .dark, let darkHex = fromMember?.colorHexDark {
                return Color(hex: darkHex)
            }
            return Color(hex: fromMember?.colorHex ?? "#007AFF")
        }()

        let toColor: Color = {
            if colorScheme == .dark, let darkHex = toMember?.colorHexDark {
                return Color(hex: darkHex)
            }
            return Color(hex: toMember?.colorHex ?? "#007AFF")
        }()

        return HStack(spacing: Theme.spacing12) {
            // From avatar
            Image(systemName: fromMember?.avatarName ?? "person.circle.fill")
                .font(.title3)
                .foregroundColor(fromColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(fromMember?.name ?? "Unknown")
                    .font(.body)
                    .foregroundColor(Theme.textPrimary)
                Text("owes")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(Theme.textTertiary)

            // To avatar
            Image(systemName: toMember?.avatarName ?? "person.circle.fill")
                .font(.title3)
                .foregroundColor(toColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(toMember?.name ?? "Unknown")
                    .font(.body)
                    .foregroundColor(Theme.textPrimary)
                Text("owes")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Text(formatDecimal(debt.amount))
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(fromMember?.name ?? "Unknown") owes \(toMember?.name ?? "Unknown") \(formatDecimal(debt.amount))")
    }

    // MARK: - Helpers

    private func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}
