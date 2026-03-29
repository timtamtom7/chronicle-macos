import Foundation

/// R17: Team and Enterprise features
/// Team workspace, members, roles, and audit logging

// MARK: - Team Model

struct Team: Identifiable, Codable {
    let id: UUID
    var name: String
    var adminId: UUID
    var members: [TeamMember]
    var bills: [UUID] // team-shared bill IDs
    var policy: TeamPolicy
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        adminId: UUID,
        members: [TeamMember] = [],
        bills: [UUID] = [],
        policy: TeamPolicy = TeamPolicy(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.adminId = adminId
        self.members = members
        self.bills = bills
        self.policy = policy
        self.createdAt = createdAt
    }
}

// MARK: - Team Member

struct TeamMember: Identifiable, Codable {
    let id: UUID
    var userId: UUID
    var name: String
    var email: String?
    var role: TeamRole
    var joinedAt: Date
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        email: String? = nil,
        role: TeamRole = .member,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.email = email
        self.role = role
        self.joinedAt = joinedAt
    }
}

// MARK: - Team Role

enum TeamRole: String, Codable {
    case admin
    case member
    case viewer
}

// MARK: - Team Policy

struct TeamPolicy: Codable {
    var requireCategory: Bool = false
    var blockPersonalBills: Bool = false
    var defaultReminderDays: Int = 3
    var allowedCategories: [Category]? = nil // nil = all allowed
    
    init(
        requireCategory: Bool = false,
        blockPersonalBills: Bool = false,
        defaultReminderDays: Int = 3,
        allowedCategories: [Category]? = nil
    ) {
        self.requireCategory = requireCategory
        self.blockPersonalBills = blockPersonalBills
        self.defaultReminderDays = defaultReminderDays
        self.allowedCategories = allowedCategories
    }
}

// MARK: - Audit Log Entry

struct AuditLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let actorId: UUID
    let actorName: String
    let action: AuditAction
    let entityType: String
    let entityId: UUID
    let details: [String: String]? // e.g., ["oldAmount": "100", "newAmount": "150"]
    let ipAddress: String?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        actorId: UUID,
        actorName: String,
        action: AuditAction,
        entityType: String,
        entityId: UUID,
        details: [String: String]? = nil,
        ipAddress: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actorId = actorId
        self.actorName = actorName
        self.action = action
        self.entityType = entityType
        self.entityId = entityId
        self.details = details
        self.ipAddress = ipAddress
    }
}

// MARK: - Audit Action

enum AuditAction: String, Codable {
    case billCreated
    case billUpdated
    case billDeleted
    case billPaid
    case billUnpaid
    case memberInvited
    case memberJoined
    case memberRemoved
    case memberRoleChanged
    case policyUpdated
    case teamCreated
}
