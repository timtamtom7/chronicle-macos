import Foundation

/// Platform-agnostic data store interface for Chronicle.
/// Implementations exist for each platform (FileManager on Apple,
/// Android Storage on Android, IndexedDB on web).
public protocol ChronicleDataStore: Sendable {
    func loadBills() async throws -> [Bill]
    func saveBills(_ bills: [Bill]) async throws
    func loadSpendingHistory() async throws -> [MonthlySpending]
    func saveSpendingHistory(_ history: [MonthlySpending]) async throws
    func loadSettings() async throws -> ChronicleSettings
    func saveSettings(_ settings: ChronicleSettings) async throws
}

public struct ChronicleSettings: Codable, Sendable {
    public var notificationsEnabled: Bool
    public var defaultReminderDays: Int
    public var currencySymbol: String
    public var sortOrder: SortOrder
    public var groupByCategory: Bool

    public init(
        notificationsEnabled: Bool = true,
        defaultReminderDays: Int = 1,
        currencySymbol: String = "$",
        sortOrder: SortOrder = .dueDay,
        groupByCategory: Bool = false
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.defaultReminderDays = defaultReminderDays
        self.currencySymbol = currencySymbol
        self.sortOrder = sortOrder
        self.groupByCategory = groupByCategory
    }
}

public enum SortOrder: String, Codable, CaseIterable, Sendable {
    case dueDay
    case amount
    case name
    case category
    case createdAt
}
