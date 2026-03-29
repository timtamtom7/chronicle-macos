import Foundation

/// R17: Team management service
/// Handles team CRUD, member invitations, role management
final class TeamService: ObservableObject {
    
    static let shared = TeamService()
    
    @Published private(set) var currentTeam: Team?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    private let userDefaultsKey = "chronicle_current_team"
    
    private init() {
        loadCurrentTeam()
    }
    
    // MARK: - Team CRUD
    
    /// Creates a new team with the caller as admin
    func createTeam(name: String) -> Team {
        let adminId = UUID() // Would come from auth service in production
        let team = Team(
            id: UUID(),
            name: name,
            adminId: adminId,
            members: [],
            bills: [],
            policy: TeamPolicy(),
            createdAt: Date()
        )
        currentTeam = team
        saveCurrentTeam()
        
        // Log team creation
        AuditLogService.shared.log(
            .teamCreated,
            entity: .team(id: team.id),
            details: ["teamName": name]
        )
        
        return team
    }
    
    func updateTeam(_ team: Team) {
        currentTeam = team
        saveCurrentTeam()
    }
    
    func deleteTeam() {
        currentTeam = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    // MARK: - Member Management
    
    /// Generates an invite link for a new member
    func inviteMember(email: String, role: TeamRole) -> String {
        guard var team = currentTeam else {
            errorMessage = "No team selected"
            return ""
        }
        
        let memberId = UUID()
        let inviteCode = generateInviteCode()
        
        let member = TeamMember(
            id: memberId,
            userId: UUID(),
            name: "", // Will be set when member joins
            email: email,
            role: role,
            joinedAt: Date()
        )
        
        // Store invite code mapping (in production, this would be server-side)
        let inviteKey = "invite_\(inviteCode)"
        if let inviteData = try? JSONEncoder().encode(member) {
            UserDefaults.standard.set(inviteData, forKey: inviteKey)
        }
        
        AuditLogService.shared.log(
            .memberInvited,
            entity: .member(id: memberId),
            details: ["email": email, "role": role.rawValue]
        )
        
        return inviteCode
    }
    
    /// Removes a member from the team
    func removeMember(id: UUID) {
        guard var team = currentTeam else {
            errorMessage = "No team selected"
            return
        }
        
        guard let index = team.members.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Member not found"
            return
        }
        
        let member = team.members[index]
        team.members.remove(at: index)
        currentTeam = team
        saveCurrentTeam()
        
        AuditLogService.shared.log(
            .memberRemoved,
            entity: .member(id: id),
            details: ["email": member.email ?? "unknown"]
        )
    }
    
    /// Updates a member's role
    func updateMemberRole(id: UUID, role: TeamRole) {
        guard var team = currentTeam else {
            errorMessage = "No team selected"
            return
        }
        
        guard let index = team.members.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Member not found"
            return
        }
        
        let oldRole = team.members[index].role
        team.members[index].role = role
        currentTeam = team
        saveCurrentTeam()
        
        AuditLogService.shared.log(
            .memberRoleChanged,
            entity: .member(id: id),
            details: ["oldRole": oldRole.rawValue, "newRole": role.rawValue]
        )
    }
    
    // MARK: - Policy Management
    
    /// Updates the team policy
    func applyPolicy(_ policy: TeamPolicy) {
        guard var team = currentTeam else {
            errorMessage = "No team selected"
            return
        }
        
        team.policy = policy
        currentTeam = team
        saveCurrentTeam()
        
        AuditLogService.shared.log(
            .policyUpdated,
            entity: .team(id: team.id),
            details: [
                "requireCategory": String(policy.requireCategory),
                "blockPersonalBills": String(policy.blockPersonalBills),
                "defaultReminderDays": String(policy.defaultReminderDays)
            ]
        )
    }
    
    // MARK: - Team Bills
    
    /// Marks a bill as team-shared
    func addTeamBill(billId: UUID) {
        guard var team = currentTeam else {
            errorMessage = "No team selected"
            return
        }
        
        if !team.bills.contains(billId) {
            team.bills.append(billId)
            currentTeam = team
            saveCurrentTeam()
        }
    }
    
    /// Gets all team-shared bills
    func getTeamBills() -> [Bill] {
        guard let team = currentTeam else { return [] }
        
        // Fetch bills from BillStore
        let allBills = BillStore.shared.bills
        return allBills.filter { team.bills.contains($0.id) }
    }
    
    // MARK: - Persistence
    
    private func loadCurrentTeam() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let team = try? JSONDecoder().decode(Team.self, from: data) else {
            return
        }
        currentTeam = team
    }
    
    private func saveCurrentTeam() {
        guard let team = currentTeam,
              let data = try? JSONEncoder().encode(team) else {
            return
        }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
    
    private func generateInviteCode() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }
}

// MARK: - Audit Entity Helper

extension AuditLogService {
    enum AuditEntity {
        case team(id: UUID)
        case member(id: UUID)
        case bill(id: UUID)
        
        var type: String {
            switch self {
            case .team: return "team"
            case .member: return "member"
            case .bill: return "bill"
            }
        }
        
        var id: UUID {
            switch self {
            case .team(let id), .member(let id), .bill(let id):
                return id
            }
        }
    }
}
