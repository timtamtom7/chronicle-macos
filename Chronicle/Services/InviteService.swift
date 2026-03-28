import Foundation

// MARK: - Household Invite

struct HouseholdInvite: Codable {
    let code: String
    let householdId: UUID
    let createdAt: Date
    let expiresAt: Date
    let createdBy: UUID

    var isValid: Bool {
        Date() < expiresAt
    }

    var inviteLink: String {
        "chronicle://join?code=\(code)"
    }
}

// MARK: - Invite Service

@MainActor
final class InviteService: ObservableObject {
    static let shared = InviteService()

    private let appGroupId = "group.com.chronicle.macos.household"
    private let inviteKey = "household_invite"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    private init() {}

    // MARK: - Generate

    func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = String((0..<8).map { _ in characters.randomElement()! })
        return code
    }

    func createInvite(for householdId: UUID, createdBy memberId: UUID) -> HouseholdInvite {
        let code = generateInviteCode()
        let invite = HouseholdInvite(
            code: code,
            householdId: householdId,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60),
            createdBy: memberId
        )
        saveInvite(invite)
        return invite
    }

    // MARK: - Retrieve

    func getInviteCode() -> HouseholdInvite? {
        guard let defaults = sharedDefaults ?? UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: inviteKey),
              let invite = try? JSONDecoder().decode(HouseholdInvite.self, from: data) else {
            return nil
        }
        guard invite.isValid else {
            revokeInvite()
            return nil
        }
        return invite
    }

    // MARK: - Join

    func joinWithCode(_ code: String) -> Bool {
        guard let invite = getInviteCode(),
              invite.code == code.uppercased(),
              invite.isValid else {
            return false
        }

        let householdService = HouseholdService.shared
        guard let household = householdService.household else { return false }

        // Add current member to household
        if let member = householdService.currentMember,
           !household.members.contains(where: { $0.id == member.id }) {
            householdService.addMember(name: member.name, avatarName: member.avatarName, colorHex: member.colorHex)
        }

        NotificationCenter.default.post(name: .householdDidChange, object: nil)
        return true
    }

    // MARK: - Revoke

    func revokeInvite() {
        if let defaults = sharedDefaults ?? UserDefaults(suiteName: appGroupId) {
            defaults.removeObject(forKey: inviteKey)
        }
    }

    // MARK: - Private

    private func saveInvite(_ invite: HouseholdInvite) {
        guard let defaults = sharedDefaults ?? UserDefaults(suiteName: appGroupId),
              let data = try? JSONEncoder().encode(invite) else {
            return
        }
        defaults.set(data, forKey: inviteKey)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let householdDidChange = Notification.Name("householdDidChange")
}
