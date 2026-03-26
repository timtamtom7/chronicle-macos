import Foundation

/// R17: Team and Enterprise features
/// Team workspace, members, roles, and audit logging

// MARK: - Team Model

struct Team: Codable, Identifiable {
    let id: UUID
    var name: String
    var members: [TeamMember]
    var teamBills: [Bill]
    var settings: TeamSettings
    var createdAt: Date
    var subscriptionTier: SubscriptionTier
    
    init(
        id: UUID = UUID(),
        name: String,
        members: [TeamMember] = [],
        teamBills: [Bill] = [],
        settings: TeamSettings = TeamSettings(),
        createdAt: Date = Date(),
        subscriptionTier: SubscriptionTier = .enterprise
    ) {
        self.id = id
        self.name = name
        self.members = members
        self.teamBills = teamBills
        self.settings = settings
        self.createdAt = createdAt
        self.subscriptionTier = subscriptionTier
    }
}

// MARK: - Team Member

struct TeamMember: Codable, Identifiable {
    let id: UUID
    var email: String
    var name: String
    var role: TeamRole
    var status: MemberStatus
    var joinedAt: Date
    var lastActiveAt: Date?
    var visibleBillCategories: [String]?
    
    init(
        id: UUID = UUID(),
        email: String,
        name: String,
        role: TeamRole = .member,
        status: MemberStatus = .pending,
        joinedAt: Date = Date(),
        lastActiveAt: Date? = nil,
        visibleBillCategories: [String]? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
        self.status = status
        self.joinedAt = joinedAt
        self.lastActiveAt = lastActiveAt
        self.visibleBillCategories = visibleBillCategories
    }
}

enum TeamRole: String, Codable, CaseIterable {
    case admin
    case member
    case viewer
    
    var displayName: String {
        switch self {
        case .admin: return "Admin"
        case .member: return "Member"
        case .viewer: return "Viewer"
        }
    }
    
    var canManageTeam: Bool { self == .admin }
    var canEditBills: Bool { self == .admin || self == .member }
    var canViewBills: Bool { true }
    var canExportData: Bool { self == .admin }
}

enum MemberStatus: String, Codable {
    case pending
    case active
    case suspended
    case removed
}

// MARK: - Team Settings

struct TeamSettings: Codable {
    var dataResidency: DataResidency
    var requireSSO: Bool
    var allowedDomains: [String]
    var defaultReminderDays: Int
    var enforceCategories: Bool
    var blockedCategories: [String]
    var auditLogRetentionDays: Int
    
    init(
        dataResidency: DataResidency = .us,
        requireSSO: Bool = false,
        allowedDomains: [String] = [],
        defaultReminderDays: Int = 3,
        enforceCategories: Bool = false,
        blockedCategories: [String] = [],
        auditLogRetentionDays: Int = 730
    ) {
        self.dataResidency = dataResidency
        self.requireSSO = requireSSO
        self.allowedDomains = allowedDomains
        self.defaultReminderDays = defaultReminderDays
        self.enforceCategories = enforceCategories
        self.blockedCategories = blockedCategories
        self.auditLogRetentionDays = auditLogRetentionDays
    }
}

enum DataResidency: String, Codable, CaseIterable {
    case us = "US"
    case eu = "EU"
    case apac = "APAC"
    case global = "Global"
}

// MARK: - Audit Log

struct AuditLogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let actorId: UUID
    let actorEmail: String
    let actorName: String
    let action: AuditAction
    let resourceType: String
    let resourceId: UUID?
    let details: [String: String]
    let ipAddress: String?
    let userAgent: String?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        actorId: UUID,
        actorEmail: String,
        actorName: String,
        action: AuditAction,
        resourceType: String,
        resourceId: UUID? = nil,
        details: [String: String] = [:],
        ipAddress: String? = nil,
        userAgent: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actorId = actorId
        self.actorEmail = actorEmail
        self.actorName = actorName
        self.action = action
        self.resourceType = resourceType
        self.resourceId = resourceId
        self.details = details
        self.ipAddress = ipAddress
        self.userAgent = userAgent
    }
}

enum AuditAction: String, Codable {
    case billCreated = "bill.created"
    case billUpdated = "bill.updated"
    case billDeleted = "bill.deleted"
    case billPaid = "bill.paid"
    case billUnpaid = "bill.unpaid"
    case memberInvited = "member.invited"
    case memberAdded = "member.added"
    case memberRemoved = "member.removed"
    case memberRoleChanged = "member.role_changed"
    case teamCreated = "team.created"
    case teamSettingsChanged = "team.settings_changed"
    case subscriptionChanged = "subscription.changed"
    case dataExported = "data.exported"
    case dataDeleted = "data.deleted"
}

// MARK: - SSO Configuration (R17)

struct SSOConfiguration: Codable {
    var enabled: Bool
    var idpType: IdentityProvider
    var ssoURL: String?
    var certificateData: Data?
    var metadataURL: String?
    var allowedDomains: [String]
    
    init(
        enabled: Bool = false,
        idpType: IdentityProvider = .okta,
        ssoURL: String? = nil,
        certificateData: Data? = nil,
        metadataURL: String? = nil,
        allowedDomains: [String] = []
    ) {
        self.enabled = enabled
        self.idpType = idpType
        self.ssoURL = ssoURL
        self.certificateData = certificateData
        self.metadataURL = metadataURL
        self.allowedDomains = allowedDomains
    }
}

enum IdentityProvider: String, Codable, CaseIterable {
    case okta = "Okta"
    case azureAD = "Azure AD"
    case googleWorkspace = "Google Workspace"
    case genericSAML = "Generic SAML 2.0"
}

// MARK: - MDM Configuration (R17)

struct MDMConfiguration: Codable {
    var enabled: Bool
    var managedAppleIdRequired: Bool
    var preconfiguredTeamId: UUID?
    var forceCategories: Bool
    var blockedPersonalBills: Bool
    var defaultReminderDays: Int
    var allowDataExport: Bool
    var remoteWipeEnabled: Bool
    
    init(
        enabled: Bool = false,
        managedAppleIdRequired: Bool = false,
        preconfiguredTeamId: UUID? = nil,
        forceCategories: Bool = false,
        blockedPersonalBills: Bool = false,
        defaultReminderDays: Int = 3,
        allowDataExport: Bool = true,
        remoteWipeEnabled: Bool = false
    ) {
        self.enabled = enabled
        self.managedAppleIdRequired = managedAppleIdRequired
        self.preconfiguredTeamId = preconfiguredTeamId
        self.forceCategories = forceCategories
        self.blockedPersonalBills = blockedPersonalBills
        self.defaultReminderDays = defaultReminderDays
        self.allowDataExport = allowDataExport
        self.remoteWipeEnabled = remoteWipeEnabled
    }
}
