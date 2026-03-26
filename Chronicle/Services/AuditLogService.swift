import Foundation

/// R17: Immutable audit logging service
/// Records all significant changes for compliance reporting
final class AuditLogService: ObservableObject {
    
    static let shared = AuditLogService()
    
    @Published private(set) var entries: [AuditLogEntry] = []
    
    private let storageKey = "chronicle_audit_log"
    private let maxEntries = 10000 // 2 years at ~5 entries/day
    
    private init() {
        loadEntries()
    }
    
    // MARK: - Add Entry
    
    internal func addEntry(_ entry: AuditLogEntry) {
        entries.insert(entry, at: 0) // Most recent first
        
        // Trim old entries if over limit
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        
        saveEntries()
    }
    
    // MARK: - Query
    
    internal func entriesForResource(type: String, id: UUID) -> [AuditLogEntry] {
        entries.filter { $0.resourceType == type && $0.resourceId == id }
    }
    
    internal func entriesByActor(_ actorId: UUID) -> [AuditLogEntry] {
        entries.filter { $0.actorId == actorId }
    }
    
    internal func entriesInRange(from: Date, to: Date) -> [AuditLogEntry] {
        entries.filter { $0.timestamp >= from && $0.timestamp <= to }
    }
    
    internal func entries(action: AuditAction) -> [AuditLogEntry] {
        entries.filter { $0.action == action }
    }
    
    // MARK: - Export
    
    internal func exportAsCSV() -> String {
        var csv = "ID,Timestamp,Actor Email,Actor Name,Action,Resource Type,Resource ID,Details\n"
        
        let dateFormatter = ISO8601DateFormatter()
        
        for entry in entries {
            let details = entry.details.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
            let row = [
                entry.id.uuidString,
                dateFormatter.string(from: entry.timestamp),
                entry.actorEmail,
                entry.actorName,
                entry.action.rawValue,
                entry.resourceType,
                entry.resourceId?.uuidString ?? "",
                details
            ].map { "\"\($0)\"" }.joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
    
    internal func exportAsJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries)
    }
    
    // MARK: - Cleanup
    
    internal func purgeOldEntries(olderThan days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        entries = entries.filter { $0.timestamp >= cutoff }
        saveEntries()
    }
    
    // MARK: - Persistence
    
    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AuditLogEntry].self, from: data) else {
            return
        }
        entries = decoded
    }
    
    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
