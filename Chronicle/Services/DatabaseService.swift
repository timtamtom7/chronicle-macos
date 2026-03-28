import Foundation
import SQLite

final class DatabaseService {
    static let shared = DatabaseService()

    private var db: Connection?
    private let schemaVersionKey = "chronicleSchemaVersion"
    private let currentSchemaVersion = 3

    // MARK: - Table Definitions

    private let bills = Table("bills")
    private let id = Expression<String>("id")
    private let name = Expression<String>("name")
    private let amountCents = Expression<Int>("amount_cents")
    private let currency = Expression<String>("currency")
    private let dueDay = Expression<Int>("due_day")
    private let dueDate = Expression<Date>("due_date")
    private let recurrence = Expression<String>("recurrence")
    private let category = Expression<String>("category")
    private let notes = Expression<String?>("notes")
    private let reminderTimings = Expression<String>("reminder_timings")
    private let autoMarkPaid = Expression<Bool>("auto_mark_paid")
    private let isActive = Expression<Bool>("is_active")
    private let isPaid = Expression<Bool>("is_paid")
    private let createdAt = Expression<Date>("created_at")
    private let isTaxDeductible = Expression<Bool>("is_tax_deductible")
    private let businessTag = Expression<String?>("business_tag")
    private let isReimbursable = Expression<Bool>("is_reimbursable")
    private let invoiceReference = Expression<String?>("invoice_reference")
    private let attachedInvoicePath = Expression<String?>("attached_invoice_path")
    private let originalAmount = Expression<Double?>("original_amount")
    private let originalCurrency = Expression<String?>("original_currency")
    private let receiptPath = Expression<String?>("receipt_path")

    private let paymentRecords = Table("payment_records")
    private let prId = Expression<String>("id")
    private let prBillId = Expression<String>("bill_id")
    private let amountPaidCents = Expression<Int>("amount_paid_cents")
    private let paidAt = Expression<Date>("paid_at")

    // MARK: - Init

    private init() {
        setupDatabase()
        applyMigrations()
    }

    private func setupDatabase() {
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appFolder = appSupport.appendingPathComponent("Chronicle", isDirectory: true)

            if !FileManager.default.fileExists(atPath: appFolder.path) {
                try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            }

            let dbPath = appFolder.appendingPathComponent("chronicle.db").path
            db = try Connection(dbPath)

            try createTables()
        } catch {
            print("Database setup error: \(error)")
        }
    }

    private func createTables() throws {
        guard let db = db else { return }

        try db.run(bills.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(name)
            t.column(amountCents)
            t.column(currency)
            t.column(dueDay)
            t.column(dueDate)
            t.column(recurrence)
            t.column(category)
            t.column(notes)
            t.column(reminderTimings)
            t.column(autoMarkPaid)
            t.column(isActive)
            t.column(isPaid)
            t.column(createdAt)
            t.column(isTaxDeductible)
            t.column(businessTag)
            t.column(isReimbursable)
            t.column(invoiceReference)
            t.column(attachedInvoicePath)
            t.column(originalAmount)
            t.column(originalCurrency)
            t.column(receiptPath)
        })

        try db.run(paymentRecords.create(ifNotExists: true) { t in
            t.column(prId, primaryKey: true)
            t.column(prBillId)
            t.column(amountPaidCents)
            t.column(paidAt)
        })
    }

    // MARK: - Migrations

    private func applyMigrations() {
        let savedVersion = UserDefaults.standard.integer(forKey: schemaVersionKey)

        if savedVersion < 2 {
            migrateToV2()
        }

        if savedVersion < 3 {
            migrateToV3()
        }

        UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
    }

    private func migrateToV2() {
        guard let db = db else { return }

        do {
            var columnNames: [String] = []
            for row in try db.prepare("PRAGMA table_info(bills)") {
                if let name = row[0] as? String {
                    columnNames.append(name)
                }
            }

            if !columnNames.contains("currency") {
                try db.execute("ALTER TABLE bills ADD COLUMN currency TEXT NOT NULL DEFAULT 'USD'")
            }
        } catch {
            print("Migration V2 failed: \(error)")
        }
    }

    private func migrateToV3() {
        guard let db = db else { return }

        do {
            var columnNames: [String] = []
            for row in try db.prepare("PRAGMA table_info(bills)") {
                if let name = row[0] as? String {
                    columnNames.append(name)
                }
            }

            if !columnNames.contains("is_tax_deductible") {
                try db.execute("ALTER TABLE bills ADD COLUMN is_tax_deductible INTEGER NOT NULL DEFAULT 0")
            }
            if !columnNames.contains("business_tag") {
                try db.execute("ALTER TABLE bills ADD COLUMN business_tag TEXT")
            }
            if !columnNames.contains("is_reimbursable") {
                try db.execute("ALTER TABLE bills ADD COLUMN is_reimbursable INTEGER NOT NULL DEFAULT 0")
            }
            if !columnNames.contains("invoice_reference") {
                try db.execute("ALTER TABLE bills ADD COLUMN invoice_reference TEXT")
            }
            if !columnNames.contains("attached_invoice_path") {
                try db.execute("ALTER TABLE bills ADD COLUMN attached_invoice_path TEXT")
            }
            if !columnNames.contains("original_amount") {
                try db.execute("ALTER TABLE bills ADD COLUMN original_amount REAL")
            }
            if !columnNames.contains("original_currency") {
                try db.execute("ALTER TABLE bills ADD COLUMN original_currency TEXT")
            }
            if !columnNames.contains("receipt_path") {
                try db.execute("ALTER TABLE bills ADD COLUMN receipt_path TEXT")
            }
        } catch {
            print("Migration V3 failed: \(error)")
        }
    }

    // MARK: - Bill CRUD

    func insertBill(_ bill: Bill) throws {
        guard let db = db else { return }

        let reminderTimingsJson = (try? JSONEncoder().encode(bill.reminderTimings).base64EncodedString()) ?? "[]"

        try db.run(bills.insert(
            id <- bill.id.uuidString,
            name <- bill.name,
            amountCents <- bill.amountCents,
            currency <- bill.currency.rawValue,
            dueDay <- bill.dueDay,
            dueDate <- bill.dueDate,
            recurrence <- bill.recurrence.rawValue,
            category <- bill.category.rawValue,
            notes <- bill.notes,
            reminderTimings <- reminderTimingsJson,
            autoMarkPaid <- bill.autoMarkPaid,
            isActive <- bill.isActive,
            isPaid <- bill.isPaid,
            createdAt <- bill.createdAt,
            isTaxDeductible <- bill.isTaxDeductible,
            businessTag <- bill.businessTag?.rawValue,
            isReimbursable <- bill.isReimbursable,
            invoiceReference <- bill.invoiceReference,
            attachedInvoicePath <- bill.attachedInvoiceURL?.path,
            originalAmount <- bill.originalAmount.map { NSDecimalNumber(decimal: $0).doubleValue },
            originalCurrency <- bill.originalCurrency?.rawValue,
            receiptPath <- bill.receiptURL?.path
        ))
    }

    func updateBill(_ bill: Bill) throws {
        guard let db = db else { return }

        let reminderTimingsJson = (try? JSONEncoder().encode(bill.reminderTimings).base64EncodedString()) ?? "[]"

        let billRow = bills.filter(id == bill.id.uuidString)
        try db.run(billRow.update(
            name <- bill.name,
            amountCents <- bill.amountCents,
            currency <- bill.currency.rawValue,
            dueDay <- bill.dueDay,
            dueDate <- bill.dueDate,
            recurrence <- bill.recurrence.rawValue,
            category <- bill.category.rawValue,
            notes <- bill.notes,
            reminderTimings <- reminderTimingsJson,
            autoMarkPaid <- bill.autoMarkPaid,
            isActive <- bill.isActive,
            isPaid <- bill.isPaid,
            isTaxDeductible <- bill.isTaxDeductible,
            businessTag <- bill.businessTag?.rawValue,
            isReimbursable <- bill.isReimbursable,
            invoiceReference <- bill.invoiceReference,
            attachedInvoicePath <- bill.attachedInvoiceURL?.path,
            originalAmount <- bill.originalAmount.map { NSDecimalNumber(decimal: $0).doubleValue },
            originalCurrency <- bill.originalCurrency?.rawValue,
            receiptPath <- bill.receiptURL?.path
        ))
    }

    func deleteBill(_ billId: UUID) throws {
        guard let db = db else { return }

        let billRow = bills.filter(id == billId.uuidString)
        try db.run(billRow.delete())

        let records = paymentRecords.filter(prBillId == billId.uuidString)
        try db.run(records.delete())
    }

    func fetchAllBills() throws -> [Bill] {
        guard let db = db else { return [] }

        var result: [Bill] = []
        for row in try db.prepare(bills) {
            let bill = billFromRow(row)
            result.append(bill)
        }
        return result
    }

    func markBillPaid(_ billId: UUID, paid: Bool) throws {
        guard let db = db else { return }

        let billRow = bills.filter(id == billId.uuidString)
        try db.run(billRow.update(isPaid <- paid))

        if paid {
            if let bill = try fetchBill(by: billId) {
                let record = PaymentRecord(
                    billId: billId,
                    amountPaidCents: bill.amountCents
                )
                try insertPaymentRecord(record)
            }
        }
    }

    private func billFromRow(_ row: Row) -> Bill {
        let reminderTimingsStr = row[reminderTimings]
        let decodedTimings: [ReminderTiming] = {
            guard let data = Data(base64Encoded: reminderTimingsStr),
                  let decoded = try? JSONDecoder().decode([ReminderTiming].self, from: data) else {
                return []
            }
            return decoded
        }()

        let currencyStr = row[currency]
        let currencyEnum = Currency(rawValue: currencyStr) ?? .usd

        let tagStr = row[businessTag]
        let businessTagEnum: BusinessTag? = tagStr.flatMap { BusinessTag(rawValue: $0) }

        let invoicePath = row[attachedInvoicePath]
        let invoiceURL: URL? = invoicePath.flatMap { URL(fileURLWithPath: $0) }

        let origAmount: Decimal? = row[originalAmount].map { Decimal($0) }
        let origCurrency: Currency? = row[originalCurrency].flatMap { Currency(rawValue: $0) }
        let receiptURL: URL? = row[receiptPath].flatMap { URL(fileURLWithPath: $0) }

        return Bill(
            id: UUID(uuidString: row[id]) ?? UUID(),
            name: row[name],
            amountCents: row[amountCents],
            currency: currencyEnum,
            dueDay: row[dueDay],
            dueDate: row[dueDate],
            recurrence: Recurrence(rawValue: row[recurrence]) ?? .none,
            category: Category(rawValue: row[category]) ?? .other,
            notes: row[notes],
            reminderTimings: decodedTimings,
            autoMarkPaid: row[autoMarkPaid],
            isActive: row[isActive],
            isPaid: row[isPaid],
            createdAt: row[createdAt],
            isTaxDeductible: row[isTaxDeductible],
            businessTag: businessTagEnum,
            isReimbursable: row[isReimbursable],
            invoiceReference: row[invoiceReference],
            attachedInvoiceURL: invoiceURL,
            originalAmount: origAmount,
            originalCurrency: origCurrency,
            receiptURL: receiptURL
        )
    }

    func fetchBill(by billId: UUID) throws -> Bill? {
        guard let db = db else { return nil }

        let query = bills.filter(id == billId.uuidString)
        if let row = try db.pluck(query) {
            return billFromRow(row)
        }
        return nil
    }

    // MARK: - Payment Records

    func insertPaymentRecord(_ record: PaymentRecord) throws {
        guard let db = db else { return }

        try db.run(paymentRecords.insert(
            prId <- record.id.uuidString,
            prBillId <- record.billId.uuidString,
            amountPaidCents <- record.amountPaidCents,
            paidAt <- record.paidAt
        ))
    }

    func fetchPaymentRecords(for billId: UUID) throws -> [PaymentRecord] {
        guard let db = db else { return [] }

        var result: [PaymentRecord] = []
        let query = paymentRecords.filter(prBillId == billId.uuidString).order(paidAt.desc)

        for row in try db.prepare(query) {
            let record = PaymentRecord(
                id: UUID(uuidString: row[prId]) ?? UUID(),
                billId: UUID(uuidString: row[prBillId]) ?? UUID(),
                amountPaidCents: row[amountPaidCents],
                paidAt: row[paidAt]
            )
            result.append(record)
        }
        return result
    }

    func fetchAllPaymentRecords() throws -> [PaymentRecord] {
        guard let db = db else { return [] }

        var result: [PaymentRecord] = []
        for row in try db.prepare(paymentRecords.order(paidAt.desc)) {
            let record = PaymentRecord(
                id: UUID(uuidString: row[prId]) ?? UUID(),
                billId: UUID(uuidString: row[prBillId]) ?? UUID(),
                amountPaidCents: row[amountPaidCents],
                paidAt: row[paidAt]
            )
            result.append(record)
        }
        return result
    }

    func fetchPaymentRecords(forMonth yearMonth: YearMonth) throws -> [PaymentRecord] {
        guard let db = db else { return [] }

        let start = yearMonth.startDate
        let end = yearMonth.endDate

        var result: [PaymentRecord] = []
        let query = paymentRecords
            .filter(paidAt >= start && paidAt <= end)
            .order(paidAt.desc)

        for row in try db.prepare(query) {
            let record = PaymentRecord(
                id: UUID(uuidString: row[prId]) ?? UUID(),
                billId: UUID(uuidString: row[prBillId]) ?? UUID(),
                amountPaidCents: row[amountPaidCents],
                paidAt: row[paidAt]
            )
            result.append(record)
        }
        return result
    }

    func wasPaidThisPeriod(for bill: Bill, in period: YearMonth) throws -> Bool {
        guard let db = db else { return false }

        let start = period.startDate
        let end = period.endDate

        let query = paymentRecords
            .filter(prBillId == bill.id.uuidString)
            .filter(paidAt >= start && paidAt <= end)
            .limit(1)

        return try db.pluck(query) != nil
    }

    func fetchPaymentRecordsGroupedByMonth() throws -> [YearMonth: [PaymentRecord]] {
        let allRecords = try fetchAllPaymentRecords()
        var grouped: [YearMonth: [PaymentRecord]] = [:]

        for record in allRecords {
            let ym = YearMonth(date: record.paidAt)
            grouped[ym, default: []].append(record)
        }

        return grouped
    }

    func deletePaymentRecord(_ recordId: UUID) throws {
        guard let db = db else { return }
        let row = paymentRecords.filter(prId == recordId.uuidString)
        try db.run(row.delete())
    }
}
