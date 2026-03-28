import Foundation

// MARK: - Split Bill Service

/// Manages bill splitting, share tracking, and settlement for household members.
@MainActor
final class SplitBillService: ObservableObject {
    static let shared = SplitBillService()

    @Published private(set) var splits: [UUID: BillSplit] = [:]   // billId -> BillSplit
    @Published private(set) var settlements: [SettlementRecord] = []

    private let splitsKey = "chronicle_bill_splits"
    private let settlementsKey = "chronicle_settlement_records"

    private init() {
        loadSplits()
        loadSettlements()
    }

    // MARK: - Split Creation

    /// Creates a split bill from the given bill and shares.
    func createSplitBill(billId: UUID, shares: [SplitShare]) {
        let split = BillSplit(billId: billId, splits: shares)
        splits[billId] = split
        saveSplits()
    }

    /// Divides the bill equally among the given member IDs.
    func createEqualSplit(billId: UUID, memberIds: [UUID], totalAmountCents: Int) {
        let shares = SplitShare.equalSplit(billId: billId, memberIds: memberIds, totalAmountCents: totalAmountCents)
        createSplitBill(billId: billId, shares: shares)
    }

    /// Creates a custom split with per-person amounts.
    func createCustomSplit(billId: UUID, memberAmounts: [(memberId: UUID, amountCents: Int)], totalAmountCents: Int) {
        guard !memberAmounts.isEmpty else { return }
        let percentage = 100.0 / Double(memberAmounts.count)
        let shares = memberAmounts.map { item in
            SplitShare(
                memberId: item.memberId,
                amountCents: item.amountCents,
                percentage: percentage
            )
        }
        createSplitBill(billId: billId, shares: shares)
    }

    // MARK: - Share Payment

    func markSharePaid(shareId: UUID, for billId: UUID) {
        guard var billSplit = splits[billId],
              let index = billSplit.splits.firstIndex(where: { $0.id == shareId }) else { return }

        billSplit.splits[index].isPaid = true
        billSplit.splits[index].paidAt = Date()
        splits[billId] = billSplit
        saveSplits()
    }

    func markShareUnpaid(shareId: UUID, for billId: UUID) {
        guard var billSplit = splits[billId],
              let index = billSplit.splits.firstIndex(where: { $0.id == shareId }) else { return }

        billSplit.splits[index].isPaid = false
        billSplit.splits[index].paidAt = nil
        splits[billId] = billSplit
        saveSplits()
    }

    // MARK: - Settle Up

    /// Marks all shares as paid/resolved for a bill.
    func settleUp(for billId: UUID) {
        guard var billSplit = splits[billId] else { return }
        billSplit.isSettled = true
        billSplit.settledAt = Date()
        for i in billSplit.splits.indices {
            billSplit.splits[i].isPaid = true
            billSplit.splits[i].paidAt = Date()
        }
        splits[billId] = billSplit
        saveSplits()
    }

    /// Settles the entire household balance, creating settlement records to zero out all balances.
    func settleAllBalances() {
        let debts = getOwesAmounts()
        for debt in debts {
            let record = SettlementRecord(
                fromMemberId: debt.from,
                toMemberId: debt.to,
                amountCents: Int(NSDecimalNumber(decimal: debt.amount * 100).intValue)
            )
            settlements.append(record)
        }
        saveSettlements()
    }

    // MARK: - Balance Calculation

    /// Returns net balance per member in cents.
    /// Positive = member is owed money (others owe them), Negative = member owes money.
    func getRunningBalance() -> [UUID: Decimal] {
        guard let household = HouseholdService.shared.household else { return [:] }

        var balances: [UUID: Decimal] = [:]
        for member in household.members {
            balances[member.id] = 0
        }

        // For each split bill, the payer (bill owner) is owed by members who haven't paid their share.
        // Members who have paid their share have a net zero (they paid their share).
        // Members who haven't paid owe the payer.
        for (_, billSplit) in splits {
            for share in billSplit.splits {
                if share.isPaid {
                    // Member paid their share — neutral. The payer is owed and already received payment.
                    // Net balance for this member is 0 for this share.
                } else {
                    // Member owes their share — negative balance (they owe money)
                    let amount = Decimal(share.amountCents) / 100
                    balances[share.memberId, default: 0] -= amount
                }
            }
        }

        // Apply settlements
        for settlement in settlements {
            balances[settlement.fromMemberId, default: 0] += settlement.amount
            balances[settlement.toMemberId, default: 0] -= settlement.amount
        }

        return balances
    }

    /// Returns simplified debts: list of (from, to, amount) triples to settle all balances.
    /// Uses a greedy algorithm to minimize the number of transactions.
    func getOwesAmounts() -> [(from: UUID, to: UUID, amount: Decimal)] {
        let balances = getRunningBalance()

        var debtors: [(UUID, Decimal)] = []   // memberId, amount they owe (positive)
        var creditors: [(UUID, Decimal)] = [] // memberId, amount they are owed (positive)

        for (memberId, balance) in balances {
            if balance < 0 {
                debtors.append((memberId, -balance))
            } else if balance > 0 {
                creditors.append((memberId, balance))
            }
        }

        var results: [(from: UUID, to: UUID, amount: Decimal)] = []

        var debtorIndex = 0
        var creditorIndex = 0

        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let debtor = debtors[debtorIndex]
            let creditor = creditors[creditorIndex]

            let amount = min(debtor.1, creditor.1)

            if amount > 0 {
                results.append((from: debtor.0, to: creditor.0, amount: amount))
            }

            let remainingDebtor = debtor.1 - amount
            let remainingCreditor = creditor.1 - amount

            if remainingDebtor > 0 {
                debtors[debtorIndex] = (debtor.0, remainingDebtor)
                creditorIndex += 1
            } else if remainingCreditor > 0 {
                creditors[creditorIndex] = (creditor.0, remainingCreditor)
                debtorIndex += 1
            } else {
                debtorIndex += 1
                creditorIndex += 1
            }
        }

        return results
    }

    // MARK: - Accessors

    func getSplit(for billId: UUID) -> BillSplit? {
        splits[billId]
    }

    func hasSplit(for billId: UUID) -> Bool {
        splits[billId] != nil
    }

    func allSplits() -> [UUID: BillSplit] {
        splits
    }

    func deleteSplit(for billId: UUID) {
        splits.removeValue(forKey: billId)
        saveSplits()
    }

    // MARK: - Persistence

    private func saveSplits() {
        if let data = try? JSONEncoder().encode(splits) {
            UserDefaults.standard.set(data, forKey: splitsKey)
        }
    }

    private func loadSplits() {
        if let data = UserDefaults.standard.data(forKey: splitsKey),
           let loaded = try? JSONDecoder().decode([UUID: BillSplit].self, from: data) {
            splits = loaded
        }
    }

    private func saveSettlements() {
        if let data = try? JSONEncoder().encode(settlements) {
            UserDefaults.standard.set(data, forKey: settlementsKey)
        }
    }

    private func loadSettlements() {
        if let data = UserDefaults.standard.data(forKey: settlementsKey),
           let loaded = try? JSONDecoder().decode([SettlementRecord].self, from: data) {
            settlements = loaded
        }
    }
}
