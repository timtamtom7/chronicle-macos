import Foundation

/// R17: Team management service
/// Handles team CRUD, member invitations, role management
final class TeamService: ObservableObject {
    
    static let shared = TeamService()
    
    @Published private(set) var currentTeam: Team?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let userDefaultsKey = "chronicle_current_team"
    private let auditLogKey = "chronicle_audit_log"
    
    private init() {
        loadCurrentTeam()
    }
    
    // MARK: - Team CRUD
    
    internal func createTeam(name: String) -> Team {
        let team = Team(name: name)
        currentTeam = team
        saveCurrentTeam()
        log(action: .teamCreated, resourceType: "team", resourceId: team.id)
        return team
    }
    
    internal func updateTeam(_ team: Team) {
        currentTeam = team
        saveCurrentTeam()
    }
    
    internal func deleteTeam() {
        if let teamId = currentTeam?.id {
            log(action: .teamSettingsChanged, resourceType: "team", resourceId: teamId,
                details: ["action": "team_deleted"])
        }
        currentTeam = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    // MARK: - Member Management
    
    internal func inviteMember(email: String, name: String, role: TeamRole) throws {
        guard var team = currentTeam else {
            throw TeamError.noTeamSelected
        }
        
        guard team.members.count < 50 else {
            throw TeamError.teamSizeLimitReached
        }
        
        let member = TeamMember(email: email, name: name, role: role, status: .pending)
        team.members.append(member)
        currentTeam = team
        saveCurrentTeam()
        
        log(action: .memberInvited, resourceType: "member", details: [
            "email": email,
            "role": role.rawValue
        ])
        
        sendInvitationEmail(to: email, memberId: member.id)
    }
    
    internal func addMember(_ member: TeamMember) throws {
        guard var team = currentTeam else {
            throw TeamError.noTeamSelected
        }
        
        if team.members.contains(where: { $0.email == member.email }) {
            throw TeamError.memberAlreadyExists
        }
        
        team.members.append(member)
        currentTeam = team
        saveCurrentTeam()
        
        log(action: .memberAdded, resourceType: "member", resourceId: member.id, details: [
            "email": member.email,
            "role": member.role.rawValue
        ])
    }
    
    internal func removeMember(_ memberId: UUID) throws {
        guard var team = currentTeam else {
            throw TeamError.noTeamSelected
        }
        
        guard let index = team.members.firstIndex(where: { $0.id == memberId }) else {
            throw TeamError.memberNotFound
        }
        
        let member = team.members[index]
        team.members.remove(at: index)
        currentTeam = team
        saveCurrentTeam()
        
        log(action: .memberRemoved, resourceType: "member", resourceId: memberId, details: [
            "email": member.email
        ])
    }
    
    internal func updateMemberRole(_ memberId: UUID, to role: TeamRole) throws {
        guard var team = currentTeam else {
            throw TeamError.noTeamSelected
        }
        
        guard let index = team.members.firstIndex(where: { $0.id == memberId }) else {
            throw TeamError.memberNotFound
        }
        
        let oldRole = team.members[index].role
        team.members[index].role = role
        currentTeam = team
        saveCurrentTeam()
        
        log(action: .memberRoleChanged, resourceType: "member", resourceId: memberId, details: [
            "email": team.members[index].email,
            "old_role": oldRole.rawValue,
            "new_role": role.rawValue
        ])
    }
    
    // MARK: - Team Bills
    
    func addTeamBill(_ bill: Bill) throws {
        guard var team = currentTeam else {
            throw TeamError.noTeamSelected
        }
        
        team.teamBills.append(bill)
        currentTeam = team
        saveCurrentTeam()
        
        log(action: .billCreated, resourceType: "bill", resourceId: bill.id)
    }
    
    func updateTeamBill(_ bill: Bill) throws {
        guard var team = currentTeam else {
            throw TeamError.noTeamSelected
        }
        
        guard let index = team.teamBills.firstIndex(where: { $0.id == bill.id }) else {
            throw TeamError.billNotFound
        }
        
        team.teamBills[index] = bill
        currentTeam = team
        saveCurrentTeam()
        
        log(action: .billUpdated, resourceType: "bill", resourceId: bill.id)
    }
    
    // MARK: - SSO (R17)
    
    internal func configureSSO(_ config: SSOConfiguration) throws {
        guard var team = currentTeam else {
            throw TeamError.noTeamSelected
        }
        
        team.settings.requireSSO = config.enabled
        currentTeam = team
        saveCurrentTeam()
        
        log(action: .teamSettingsChanged, resourceType: "sso_config", details: [
            "enabled": String(config.enabled),
            "idp": config.idpType.rawValue
        ])
    }
    
    // MARK: - MDM (R17)
    
    internal func configureMDM(_ config: MDMConfiguration) throws {
        guard currentTeam != nil else {
            throw TeamError.noTeamSelected
        }
        
        saveCurrentTeam()
        
        log(action: .teamSettingsChanged, resourceType: "mdm_config", details: [
            "enabled": String(config.enabled)
        ])
    }
    
    internal func remoteWipe(memberId: UUID) throws {
        guard var team = currentTeam else {
            throw TeamError.noTeamSelected
        }
        
        guard let index = team.members.firstIndex(where: { $0.id == memberId }) else {
            throw TeamError.memberNotFound
        }
        
        let member = team.members[index]
        team.members[index].status = .suspended
        currentTeam = team
        saveCurrentTeam()
        
        log(action: .memberRemoved, resourceType: "member", resourceId: memberId, details: [
            "action": "remote_wipe",
            "email": member.email
        ])
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
    
    // MARK: - Audit Log
    
    private func log(action: AuditAction, resourceType: String, resourceId: UUID? = nil, details: [String: String] = [:]) {
        let entry = AuditLogEntry(
            actorId: UUID(), // Would come from auth service
            actorEmail: "current@user.com", // Would come from auth service
            actorName: "Current User",
            action: action,
            resourceType: resourceType,
            resourceId: resourceId,
            details: details
        )
        
        AuditLogService.shared.addEntry(entry)
    }
    
    private func sendInvitationEmail(to email: String, memberId: UUID) {
        // R17: Implement email invitation sending
        // Would integrate with SendGrid, Mailgun, or similar
    }
}

// MARK: - Errors

public enum TeamError: Error, LocalizedError {
    case noTeamSelected
    case teamSizeLimitReached
    case memberAlreadyExists
    case memberNotFound
    case billNotFound
    case insufficientPermissions
    case ssoConfigurationInvalid
    
    public var errorDescription: String? {
        switch self {
        case .noTeamSelected: return "No team selected"
        case .teamSizeLimitReached: return "Team size limit reached"
        case .memberAlreadyExists: return "Member already exists"
        case .memberNotFound: return "Member not found"
        case .billNotFound: return "Bill not found"
        case .insufficientPermissions: return "Insufficient permissions"
        case .ssoConfigurationInvalid: return "SSO configuration is invalid"
        }
    }
}
