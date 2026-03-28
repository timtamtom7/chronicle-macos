import Foundation

// MARK: - Household Model

struct Household: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var members: [HouseholdMember]
    var createdAt: Date
    var inviteCode: String

    init(id: UUID = UUID(), name: String, members: [HouseholdMember] = [], inviteCode: String = UUID().uuidString.prefix(8).uppercased().description) {
        self.id = id
        self.name = name
        self.members = members
        self.createdAt = Date()
        self.inviteCode = inviteCode
    }

    static func == (lhs: Household, rhs: Household) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Household Member

struct HouseholdMember: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var avatarName: String
    /// Light mode avatar color (hex)
    var colorHex: String
    /// Dark mode avatar color (hex) — falls back to colorHex if nil
    var colorHexDark: String?
    var isOwner: Bool
    var joinedAt: Date

    init(id: UUID = UUID(), name: String, avatarName: String = "person.circle.fill", colorHex: String = "#007AFF", colorHexDark: String? = nil, isOwner: Bool = false) {
        self.id = id
        self.name = name
        self.avatarName = avatarName
        self.colorHex = colorHex
        self.colorHexDark = colorHexDark
        self.isOwner = isOwner
        self.joinedAt = Date()
    }

    static let currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

// MARK: - Bill Split

struct BillSplit: Identifiable, Codable, Equatable {
    let id: UUID
    var billId: UUID
    var splits: [SplitShare]
    var settledAt: Date?
    var isSettled: Bool

    init(id: UUID = UUID(), billId: UUID, splits: [SplitShare], settledAt: Date? = nil, isSettled: Bool = false) {
        self.id = id
        self.billId = billId
        self.splits = splits
        self.settledAt = settledAt
        self.isSettled = isSettled
    }

    var totalAmount: Int {
        splits.reduce(0) { $0 + $1.amountCents }
    }

    var isFullyPaid: Bool {
        splits.allSatisfy { $0.isPaid }
    }
}

// MARK: - Split Share

struct SplitShare: Identifiable, Codable, Equatable {
    let id: UUID
    var memberId: UUID
    var amountCents: Int
    var percentage: Double
    var isPaid: Bool
    var paidAt: Date?

    init(id: UUID = UUID(), memberId: UUID, amountCents: Int, percentage: Double, isPaid: Bool = false, paidAt: Date? = nil) {
        self.id = id
        self.memberId = memberId
        self.amountCents = amountCents
        self.percentage = percentage
        self.isPaid = isPaid
        self.paidAt = paidAt
    }

    var amount: Decimal {
        Decimal(amountCents) / 100
    }

    static func equalSplit(billId: UUID, memberIds: [UUID], totalAmountCents: Int) -> [SplitShare] {
        let count = memberIds.count
        guard count > 0 else { return [] }
        let baseAmount = totalAmountCents / count
        let remainder = totalAmountCents % count
        let percentage = 100.0 / Double(count)

        return memberIds.enumerated().map { index, memberId in
            let amount = baseAmount + (index < remainder ? 1 : 0)
            return SplitShare(memberId: memberId, amountCents: amount, percentage: percentage)
        }
    }
}

// MARK: - Balance

struct MemberBalance: Identifiable {
    let id: UUID
    var memberId: UUID
    var memberName: String
    var owesCents: Int
    var owedCents: Int

    var netBalanceCents: Int {
        owedCents - owesCents
    }

    var netBalance: Decimal {
        Decimal(netBalanceCents) / 100
    }

    var isOwed: Bool {
        netBalanceCents > 0
    }

    var owes: Bool {
        netBalanceCents < 0
    }
}

// MARK: - Household Bill

struct HouseholdBill: Identifiable, Codable {
    let id: UUID
    var bill: Bill
    var ownerId: UUID
    var split: BillSplit?
    var householdId: UUID

    init(id: UUID = UUID(), bill: Bill, ownerId: UUID, split: BillSplit? = nil, householdId: UUID) {
        self.id = id
        self.bill = bill
        self.ownerId = ownerId
        self.split = split
        self.householdId = householdId
    }
}

// MARK: - Household Summary

struct HouseholdSummary {
    var totalBillsThisMonth: Int
    var totalAmountCents: Int
    var paidCount: Int
    var unpaidCount: Int
    var memberBalances: [MemberBalance]

    var totalAmount: Decimal {
        Decimal(totalAmountCents) / 100
    }

    var paidPercentage: Double {
        guard totalBillsThisMonth > 0 else { return 0 }
        return Double(paidCount) / Double(totalBillsThisMonth) * 100
    }
}
