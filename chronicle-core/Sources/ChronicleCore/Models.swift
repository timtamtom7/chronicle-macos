import Foundation

/// Shared data models for Chronicle.
/// These structs are used across macOS, iOS, Android, and web clients.
public struct Bill: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var amount: Decimal
    public var dueDay: Int // 1–31
    public var isPaid: Bool
    public var reminderDaysBefore: Int
    public var payee: String?
    public var category: BillCategory
    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        dueDay: Int,
        isPaid: Bool = false,
        reminderDaysBefore: Int = 1,
        payee: String? = nil,
        category: BillCategory = .utilities,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.dueDay = dueDay
        self.isPaid = isPaid
        self.reminderDaysBefore = reminderDaysBefore
        self.payee = payee
        self.category = category
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum BillCategory: String, Codable, CaseIterable, Sendable {
    case utilities
    case subscription
    case insurance
    case rent
    case mortgage
    case phone
    case internet
    case creditCard
    case loan
    case other
}

public struct MonthlySpending: Codable, Sendable {
    public let month: String // "YYYY-MM"
    public let totalSpent: Decimal
    public let bills: [Bill]
    public let topCategory: BillCategory?

    public init(month: String, totalSpent: Decimal, bills: [Bill], topCategory: BillCategory? = nil) {
        self.month = month
        self.totalSpent = totalSpent
        self.bills = bills
        self.topCategory = topCategory
    }
}
