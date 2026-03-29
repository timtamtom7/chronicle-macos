import Foundation
import SQLite

/// R17: Immutable audit logging service
/// Records all significant changes for compliance reporting
/// Append-only - entries are never deleted (2 year retention)
final class AuditLogService: ObservableObject {
    
    static let shared = AuditLogService()
    
    @Published private(set) var entries: [AuditLogEntry] = []
    
    private var db: Connection?
    private let retentionDays = 730 // 2 years
    
    // Table definitions
    private let auditLog = Table("audit_log")
    private let colId = Expression<String>("id")
    private let colTimestamp = Expression<Date>("timestamp")
    private let colActorId = Expression<String>("actor_id")
    private let colActorName = Expression<String>("actor_name")
    private let colAction = Expression<String>("action")
    private let colEntityType = Expression<String>("entity_type")
    private let colEntityId = Expression<String>("entity_id")
    private let colDetails = Expression<String?>("details")
    private let colIpAddress = Expression<String?>("ip_address")
    
    private init() {
        setupDatabase()
        loadEntries()
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() {
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appFolder = appSupport.appendingPathComponent("Chronicle", isDirectory: true)
            
            if !FileManager.default.fileExists(atPath: appFolder.path) {
                try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            }
            
            let dbPath = appFolder.appendingPathComponent("chronicle.db").path
            db = try Connection(dbPath)
            
            try createAuditLogTable()
        } catch {
            print("AuditLog database setup error: \(error)")
        }
    }
    
    private func createAuditLogTable() throws {
        guard let db = db else { return }
        
        try db.run(auditLog.create(ifNotExists: true) { t in
            t.column(colId, primaryKey: true)
            t.column(colTimestamp)
            t.column(colActorId)
            t.column(colActorName)
            t.column(colAction)
            t.column(colEntityType)
            t.column(colEntityId)
            t.column(colDetails)
            t.column(colIpAddress)
        })
        
        // Create index on timestamp for efficient range queries
        try db.run(auditLog.createIndex(colTimestamp, ifNotExists: true))
        try db.run(auditLog.createIndex(colActorId, ifNotExists: true))
    }
    
    // MARK: - Logging
    
    /// Logs an audit event (append-only)
    func log(_ action: AuditAction, entity: AuditEntity, details: [String: String]? = nil) {
        // In production, actor info would come from AuthService
        let actorId = UUID()
        let actorName = "Current User"
        
        let entry = AuditLogEntry(
            id: UUID(),
            timestamp: Date(),
            actorId: actorId,
            actorName: actorName,
            action: action,
            entityType: entity.type,
            entityId: entity.id,
            details: details,
            ipAddress: nil
        )
        
        insertEntry(entry)
        entries.insert(entry, at: 0) // Most recent first
    }
    
    private func insertEntry(_ entry: AuditLogEntry) {
        guard let db = db else { return }
        
        do {
            let detailsJson = entry.details.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
            
            try db.run(auditLog.insert(
                colId <- entry.id.uuidString,
                colTimestamp <- entry.timestamp,
                colActorId <- entry.actorId.uuidString,
                colActorName <- entry.actorName,
                colAction <- entry.action.rawValue,
                colEntityType <- entry.entityType,
                colEntityId <- entry.entityId.uuidString,
                colDetails <- detailsJson,
                colIpAddress <- entry.ipAddress
            ))
        } catch {
            print("Failed to insert audit log entry: \(error)")
        }
    }
    
    // MARK: - Query
    
    /// Retrieves audit log entries with optional filters
    func getEntries(for dateRange: ClosedRange<Date>? = nil, actorId: UUID? = nil) -> [AuditLogEntry] {
        guard let db = db else { return entries }
        
        do {
            var query = auditLog.order(colTimestamp.desc)
            
            if let range = dateRange {
                query = query.filter(colTimestamp >= range.lowerBound && colTimestamp <= range.upperBound)
            }
            
            if let actorId = actorId {
                query = query.filter(colActorId == actorId.uuidString)
            }
            
            var results: [AuditLogEntry] = []
            
            for row in try db.prepare(query) {
                let entry = try parseRow(row)
                results.append(entry)
            }
            
            return results
        } catch {
            print("Failed to query audit log: \(error)")
            return entries
        }
    }
    
    private func parseRow(_ row: Row) throws -> AuditLogEntry {
        let details: [String: String]?
        if let detailsJson = row[colDetails],
           let data = detailsJson.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            details = decoded
        } else {
            details = nil
        }
        
        return AuditLogEntry(
            id: UUID(uuidString: row[colId]) ?? UUID(),
            timestamp: row[colTimestamp],
            actorId: UUID(uuidString: row[colActorId]) ?? UUID(),
            actorName: row[colActorName],
            action: AuditAction(rawValue: row[colAction]) ?? .billCreated,
            entityType: row[colEntityType],
            entityId: UUID(uuidString: row[colEntityId]) ?? UUID(),
            details: details,
            ipAddress: row[colIpAddress]
        )
    }
    
    // MARK: - Export
    
    /// Exports entries to CSV format
    func exportToCSV(entries: [AuditLogEntry]) -> URL? {
        var csv = "timestamp,actor,action,entity,details\n"
        
        let dateFormatter = ISO8601DateFormatter()
        
        for entry in entries {
            let details = entry.details?.map { "\($0.key)=\($0.value)" }.joined(separator: ";") ?? ""
            let row = [
                dateFormatter.string(from: entry.timestamp),
                entry.actorName,
                entry.action.rawValue,
                "\(entry.entityType)/\(entry.entityId.uuidString)",
                details
            ].map { "\"\($0)\"" }.joined(separator: ",")
            
            csv += row + "\n"
        }
        
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let csvURL = tempDir.appendingPathComponent("audit_log_export_\(Date().timeIntervalSince1970).csv")
            try csv.write(to: csvURL, atomically: true, encoding: .utf8)
            return csvURL
        } catch {
            print("Failed to export CSV: \(error)")
            return nil
        }
    }
    
    // MARK: - Load from Database
    
    private func loadEntries() {
        guard let db = db else { return }
        
        do {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
            
            let query = auditLog
                .filter(colTimestamp >= cutoffDate)
                .order(colTimestamp.desc)
                .limit(10000) // Cap at reasonable limit
            
            entries = []
            for row in try db.prepare(query) {
                let entry = try parseRow(row)
                entries.append(entry)
            }
        } catch {
            print("Failed to load audit log: \(error)")
        }
    }
    
    // MARK: - Cleanup (only removes entries older than retention period)
    
    func cleanupOldEntries() {
        guard let db = db else { return }
        
        do {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
            try db.run(auditLog.filter(colTimestamp < cutoffDate).delete())
        } catch {
            print("Failed to cleanup old audit entries: \(error)")
        }
    }
}
