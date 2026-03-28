import Foundation

// MARK: - Business Bill Extension

struct BusinessBillInfo: Codable, Equatable {
    var isTaxDeductible: Bool
    var businessTag: BusinessTag
    var isReimbursable: Bool
    var vendorName: String?
    var invoiceNumber: String?
    var invoiceFilePath: String?
    var fiscalYear: Int?

    init(
        isTaxDeductible: Bool = false,
        businessTag: BusinessTag = .other,
        isReimbursable: Bool = false,
        vendorName: String? = nil,
        invoiceNumber: String? = nil,
        invoiceFilePath: String? = nil,
        fiscalYear: Int? = nil
    ) {
        self.isTaxDeductible = isTaxDeductible
        self.businessTag = businessTag
        self.isReimbursable = isReimbursable
        self.vendorName = vendorName
        self.invoiceNumber = invoiceNumber
        self.invoiceFilePath = invoiceFilePath
        self.fiscalYear = fiscalYear
    }
}

// MARK: - Business Tag

// Backwards compatibility alias
typealias BusinessCategory = BusinessTag

enum BusinessTag: String, CaseIterable, Codable, Identifiable {
    case office = "Office"
    case software = "Software"
    case utilities = "Utilities"
    case travel = "Travel"
    case meals = "Meals & Entertainment"
    case equipment = "Equipment"
    case marketing = "Marketing"
    case professionalServices = "Professional Services"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .office: return "building.2.fill"
        case .software: return "laptopcomputer"
        case .utilities: return "bolt.fill"
        case .travel: return "airplane"
        case .meals: return "fork.knife"
        case .equipment: return "wrench.and.screwdriver.fill"
        case .marketing: return "megaphone.fill"
        case .professionalServices: return "briefcase.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Tax Report

struct TaxReport: Identifiable, Codable {
    let id: UUID
    var year: Int
    var startDate: Date
    var endDate: Date
    var categories: [BusinessTag: Decimal]
    var totalDeductible: Decimal
    var totalReimbursable: Decimal
    var bills: [UUID]
    var generatedAt: Date

    init(
        id: UUID = UUID(),
        year: Int,
        startDate: Date,
        endDate: Date,
        categories: [BusinessTag: Decimal] = [:],
        totalDeductible: Decimal = 0,
        totalReimbursable: Decimal = 0,
        bills: [UUID] = [],
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.year = year
        self.startDate = startDate
        self.endDate = endDate
        self.categories = categories
        self.totalDeductible = totalDeductible
        self.totalReimbursable = totalReimbursable
        self.bills = bills
        self.generatedAt = generatedAt
    }
}

// MARK: - Reimbursable Bill

struct ReimbursableBill: Identifiable, Codable {
    let id: UUID
    var billId: UUID
    var amountCents: Int
    var submittedAt: Date?
    var reimbursedAt: Date?
    var status: ReimbursementStatus
    var notes: String?

    init(
        id: UUID = UUID(),
        billId: UUID,
        amountCents: Int,
        submittedAt: Date? = nil,
        reimbursedAt: Date? = nil,
        status: ReimbursementStatus = .pending,
        notes: String? = nil
    ) {
        self.id = id
        self.billId = billId
        self.amountCents = amountCents
        self.submittedAt = submittedAt
        self.reimbursedAt = reimbursedAt
        self.status = status
        self.notes = notes
    }

    var amount: Decimal {
        Decimal(amountCents) / 100
    }
}

enum ReimbursementStatus: String, Codable {
    case pending = "Pending"
    case submitted = "Submitted"
    case reimbursed = "Reimbursed"
    case rejected = "Rejected"
}

// MARK: - Accountant Mode

struct AccountantMode {
    var isEnabled: Bool
    var lockedDateRange: ClosedRange<Date>?
    var allowExport: Bool
    var readOnly: Bool

    static var disabled: AccountantMode {
        AccountantMode(isEnabled: false, lockedDateRange: nil, allowExport: false, readOnly: false)
    }
}
