import Foundation
import Combine
import AppKit

// MARK: - Household Service

@MainActor
final class HouseholdService: ObservableObject {
    static let shared = HouseholdService()

    @Published var household: Household?
    @Published var currentMember: HouseholdMember?
    @Published var balances: [MemberBalance] = []

    private let userDefaultsKey = "chronicle_household"
    private let splitsKey = "chronicle_bill_splits"

    private init() {
        loadHousehold()
    }

    // MARK: - Household Management

    func createHousehold(name: String, ownerName: String) -> Household {
        let owner = HouseholdMember(name: ownerName, isOwner: true)
        let household = Household(name: name, members: [owner])
        self.household = household
        self.currentMember = owner
        saveHousehold()
        return household
    }

    func joinHousehold(code: String) -> Bool {
        // In production, this would verify against iCloud or a server
        // For now, we support local household joining via code
        guard var household = loadHouseholdFromStorage() else { return false }
        if household.inviteCode == code {
            if let currentMember = currentMember, !household.members.contains(where: { $0.id == currentMember.id }) {
                household.members.append(currentMember)
                self.household = household
                saveHousehold()
                return true
            }
        }
        return false
    }

    func addMember(name: String, avatarName: String = "person.circle.fill", colorHex: String = "#007AFF") -> HouseholdMember? {
        guard var household = household else { return nil }
        let member = HouseholdMember(name: name, avatarName: avatarName, colorHex: colorHex)
        household.members.append(member)
        self.household = household
        saveHousehold()
        return member
    }

    func removeMember(_ memberId: UUID) {
        guard var household = household else { return }
        household.members.removeAll { $0.id == memberId }
        self.household = household
        saveHousehold()
    }

    func leaveHousehold() {
        guard let currentMember = currentMember else { return }
        removeMember(currentMember.id)
        self.currentMember = nil
    }

    // MARK: - Bill Splitting

    func splitBillEqually(_ bill: Bill, among memberIds: [UUID]) -> BillSplit {
        let splits = SplitShare.equalSplit(billId: bill.id, memberIds: memberIds, totalAmountCents: bill.amountCents)
        return BillSplit(billId: bill.id, splits: splits)
    }

    func splitBillCustom(_ bill: Bill, splits: [SplitShare]) -> BillSplit {
        return BillSplit(billId: bill.id, splits: splits)
    }

    func markSharePaid(_ splitId: UUID, for billId: UUID) {
        var splits = loadSplits()
        guard var billSplit = splits[billId] else { return }
        if let index = billSplit.splits.firstIndex(where: { $0.id == splitId }) {
            billSplit.splits[index].isPaid = true
            billSplit.splits[index].paidAt = Date()
            splits[billId] = billSplit
            saveSplits(splits)
        }
    }

    func settleUp(for billId: UUID) {
        var splits = loadSplits()
        if var billSplit = splits[billId] {
            billSplit.isSettled = true
            billSplit.settledAt = Date()
            for i in billSplit.splits.indices {
                billSplit.splits[i].isPaid = true
                billSplit.splits[i].paidAt = Date()
            }
            splits[billId] = billSplit
            saveSplits(splits)
        }
    }

    // MARK: - Balances

    func calculateBalances(bills: [HouseholdBill]) -> [MemberBalance] {
        guard let household = household else { return [] }

        var balanceMap: [UUID: (owes: Int, owed: Int)] = [:]
        for member in household.members {
            balanceMap[member.id] = (0, 0)
        }

        for householdBill in bills {
            if let split = householdBill.split {
                for share in split.splits {
                    if share.isPaid {
                        // The payer (owner) is owed by others
                        balanceMap[householdBill.ownerId, default: (0, 0)].owed += share.amountCents
                        // The member owes their share
                        balanceMap[share.memberId, default: (0, 0)].owes += share.amountCents
                    }
                }
            }
        }

        return household.members.map { member in
            let balance = balanceMap[member.id] ?? (0, 0)
            return MemberBalance(
                id: UUID(),
                memberId: member.id,
                memberName: member.name,
                owesCents: balance.owes,
                owedCents: balance.owed
            )
        }
    }

    // MARK: - QR Code Generation

    func generateInviteQRCode(for household: Household) -> NSImage? {
        let inviteString = "chronicle://join/\(household.inviteCode)"
        guard let data = inviteString.data(using: .utf8) else { return nil }

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }

        return NSImage(cgImage: cgImage, size: NSSize(width: 300, height: 300))
    }

    // MARK: - Persistence

    private func saveHousehold() {
        guard let household = household else { return }
        if let data = try? JSONEncoder().encode(household) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadHousehold() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let household = try? JSONDecoder().decode(Household.self, from: data) {
            self.household = household
            self.currentMember = household.members.first { $0.isOwner }
        }
    }

    private func loadHouseholdFromStorage() -> Household? {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let household = try? JSONDecoder().decode(Household.self, from: data) {
            return household
        }
        return nil
    }

    private func saveSplits(_ splits: [UUID: BillSplit]) {
        if let data = try? JSONEncoder().encode(splits) {
            UserDefaults.standard.set(data, forKey: splitsKey)
        }
    }

    private func loadSplits() -> [UUID: BillSplit] {
        if let data = UserDefaults.standard.data(forKey: splitsKey),
           let splits = try? JSONDecoder().decode([UUID: BillSplit].self, from: data) {
            return splits
        }
        return [:]
    }

    func getSplit(for billId: UUID) -> BillSplit? {
        loadSplits()[billId]
    }
}

// MARK: - iCloud Sync Extension

extension HouseholdService {
    func syncWithiCloud() async {
        // Placeholder for iCloud sync implementation
        // Would use NSUbiquitousKeyValueStore for household data
        // and file coordination for bill splits
    }
}
