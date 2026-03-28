import SwiftUI

// MARK: - Split Bill View

/// Shows the split breakdown for a single bill.
struct SplitBillView: View {
    @EnvironmentObject var billStore: BillStore
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var splitService = SplitBillService.shared
    @ObservedObject private var householdService = HouseholdService.shared

    let bill: Bill

    @State private var showSettleConfirm = false

    private var split: BillSplit? {
        splitService.getSplit(for: bill.id)
    }

    private var allSharesPaid: Bool {
        split?.isFullyPaid ?? false
    }

    private var unpaidCount: Int {
        split?.splits.filter { !$0.isPaid }.count ?? 0
    }

    private var paidCount: Int {
        split?.splits.filter { $0.isPaid }.count ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bill.name)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("\(split?.splits.count ?? 0) members • \(bill.formattedAmount)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                if let split = split {
                    if split.isSettled {
                        Label("Settled", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(Theme.success)
                    } else if allSharesPaid {
                        Label("All paid", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(Theme.success)
                    } else {
                        Label("\(unpaidCount) unpaid", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(Theme.warning)
                    }
                }
            }
            .padding()

            Divider()

            // Shares list
            if let split = split {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(split.splits) { share in
                            shareRow(share)
                        }
                    }
                }
                .frame(maxHeight: 300)
            } else {
                Text("No split configured")
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
                    .padding()
            }

            Divider()

            // Footer actions
            HStack {
                if let split = split, !split.isSettled {
                    if allSharesPaid {
                        Button("Settle Up") {
                            showSettleConfirm = true
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Settle up")
                        .accessibilityHint("Marks this bill as fully settled")
                    } else {
                        Text("\(paidCount)/\(split.splits.count) shares paid")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
            }
            .padding()
        }
        .frame(width: 380)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
        .alert("Settle Up?", isPresented: $showSettleConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Settle") {
                splitService.settleUp(for: bill.id)
            }
        } message: {
            Text("This will mark all shares as paid and settle the bill.")
        }
    }

    // MARK: - Share Row

    private func shareRow(_ share: SplitShare) -> some View {
        let member = householdService.household?.members.first { $0.id == share.memberId }
        let memberName = member?.name ?? "Unknown"
        let avatarColor: Color = {
            if colorScheme == .dark, let darkHex = member?.colorHexDark {
                return Color(hex: darkHex)
            }
            return Color(hex: member?.colorHex ?? "#007AFF")
        }()

        return HStack(spacing: Theme.spacing12) {
            // Avatar
            Image(systemName: member?.avatarName ?? "person.circle.fill")
                .font(.title2)
                .foregroundColor(avatarColor)
                .accessibilityHidden(true)

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(memberName)
                    .font(.body)
                    .foregroundColor(Theme.textPrimary)
                if let paidAt = share.paidAt {
                    Text("Paid \(formattedDate(paidAt))")
                        .font(.caption)
                        .foregroundColor(Theme.success)
                }
            }

            Spacer()

            // Amount
            Text(formatCents(share.amountCents))
                .font(.body)
                .foregroundColor(Theme.textPrimary)

            // Paid toggle
            Button(action: {
                if share.isPaid {
                    splitService.markShareUnpaid(shareId: share.id, for: bill.id)
                } else {
                    splitService.markSharePaid(shareId: share.id, for: bill.id)
                }
            }) {
                Image(systemName: share.isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(share.isPaid ? Theme.success : Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(share.isPaid ? "Mark \(memberName) share as unpaid" : "Mark \(memberName) share as paid")
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing8)
        .background(Theme.surface)
        .accessibilityLabel("\(memberName), \(formatCents(share.amountCents)), \(share.isPaid ? "paid" : "unpaid")")
    }

    // MARK: - Helpers

    private func formatCents(_ cents: Int) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
