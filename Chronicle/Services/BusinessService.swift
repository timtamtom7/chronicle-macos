import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Business Service

@MainActor
final class BusinessService: ObservableObject {
    static let shared = BusinessService()

    @Published var businessBills: [UUID: BusinessBillInfo] = [:]
    @Published var reimbursableBills: [ReimbursableBill] = []
    @Published var accountantMode: AccountantMode = .disabled

    private let businessKey = "chronicle_business_info"
    private let reimbursableKey = "chronicle_reimbursable"

    private init() {
        loadBusinessData()
    }

    // MARK: - Business Bill Info

    func setBusinessInfo(_ info: BusinessBillInfo, for billId: UUID) {
        businessBills[billId] = info
        saveBusinessData()
    }

    func getBusinessInfo(for billId: UUID) -> BusinessBillInfo? {
        businessBills[billId]
    }

    func clearBusinessInfo(for billId: UUID) {
        businessBills.removeValue(forKey: billId)
        saveBusinessData()
    }

    // MARK: - Reimbursable Management

    func markReimbursable(_ billId: UUID, amountCents: Int, notes: String? = nil) {
        let reimbursable = ReimbursableBill(billId: billId, amountCents: amountCents, notes: notes)
        reimbursableBills.append(reimbursable)
        saveReimbursableData()
    }

    func submitForReimbursement(_ id: UUID) {
        if let index = reimbursableBills.firstIndex(where: { $0.id == id }) {
            reimbursableBills[index].status = .submitted
            reimbursableBills[index].submittedAt = Date()
            saveReimbursableData()
        }
    }

    func markReimbursed(_ id: UUID) {
        if let index = reimbursableBills.firstIndex(where: { $0.id == id }) {
            reimbursableBills[index].status = .reimbursed
            reimbursableBills[index].reimbursedAt = Date()
            saveReimbursableData()
        }
    }

    func rejectReimbursement(_ id: UUID) {
        if let index = reimbursableBills.firstIndex(where: { $0.id == id }) {
            reimbursableBills[index].status = .rejected
            saveReimbursableData()
        }
    }

    // MARK: - Tax Reports

    func generateTaxReport(for year: Int, bills: [Bill]) -> TaxReport {
        let calendar = Calendar.current
        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = 1
        startComponents.day = 1
        let startDate = calendar.date(from: startComponents)!

        var endComponents = DateComponents()
        endComponents.year = year
        endComponents.month = 12
        endComponents.day = 31
        let endDate = calendar.date(from: endComponents)!

        var categoryTotals: [BusinessCategory: Decimal] = [:]
        var totalDeductible: Decimal = 0
        var totalReimbursable: Decimal = 0
        var billIds: [UUID] = []

        for bill in bills {
            guard bill.dueDate >= startDate && bill.dueDate <= endDate else { continue }
            guard let businessInfo = businessBills[bill.id] else { continue }

            if businessInfo.isTaxDeductible {
                billIds.append(bill.id)
                let amount = bill.amount
                categoryTotals[businessInfo.businessCategory, default: 0] += amount
                totalDeductible += amount
            }

            if businessInfo.isReimbursable {
                totalReimbursable += bill.amount
            }
        }

        return TaxReport(
            year: year,
            startDate: startDate,
            endDate: endDate,
            categories: categoryTotals,
            totalDeductible: totalDeductible,
            totalReimbursable: totalReimbursable,
            bills: billIds
        )
    }

    func exportTaxReportCSV(_ report: TaxReport, bills: [Bill]) -> URL? {
        var csv = "Category,Amount\n"
        for (category, amount) in report.categories.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            csv += "\(category.rawValue),\(amount)\n"
        }
        csv += "\nTotal Deductible,\(report.totalDeductible)\n"
        csv += "Total Reimbursable,\(report.totalReimbursable)\n"

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Chronicle_TaxReport_\(report.year).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to export CSV: \(error)")
            return nil
        }
    }

    // MARK: - Invoice Attachments

    func attachInvoice(to billId: UUID, fileURL: URL) -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let invoicesFolder = documentsPath.appendingPathComponent("Invoices", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: invoicesFolder, withIntermediateDirectories: true)
            let destURL = invoicesFolder.appendingPathComponent("\(billId.uuidString)_\(fileURL.lastPathComponent)")
            try FileManager.default.copyItem(at: fileURL, to: destURL)

            if var info = businessBills[billId] {
                info.invoiceFilePath = destURL.path
                businessBills[billId] = info
            } else {
                var info = BusinessBillInfo()
                info.invoiceFilePath = destURL.path
                businessBills[billId] = info
            }
            saveBusinessData()
            return true
        } catch {
            print("Failed to attach invoice: \(error)")
            return false
        }
    }

    func getInvoiceURL(for billId: UUID) -> URL? {
        guard let info = businessBills[billId],
              let path = info.invoiceFilePath else { return nil }
        return URL(fileURLWithPath: path)
    }

    // MARK: - Accountant Mode

    func enableAccountantMode(lockedRange: ClosedRange<Date>) {
        accountantMode = AccountantMode(
            isEnabled: true,
            lockedDateRange: lockedRange,
            allowExport: true,
            readOnly: true
        )
    }

    func disableAccountantMode() {
        accountantMode = .disabled
    }

    func isDateLocked(_ date: Date) -> Bool {
        guard accountantMode.isEnabled,
              let range = accountantMode.lockedDateRange else { return false }
        return range.contains(date)
    }

    // MARK: - Persistence

    private func saveBusinessData() {
        if let data = try? JSONEncoder().encode(businessBills) {
            UserDefaults.standard.set(data, forKey: businessKey)
        }
    }

    private func loadBusinessData() {
        if let data = UserDefaults.standard.data(forKey: businessKey),
           let info = try? JSONDecoder().decode([UUID: BusinessBillInfo].self, from: data) {
            businessBills = info
        }
    }

    private func saveReimbursableData() {
        if let data = try? JSONEncoder().encode(reimbursableBills) {
            UserDefaults.standard.set(data, forKey: reimbursableKey)
        }
    }

    private func loadReimbursableData() {
        if let data = UserDefaults.standard.data(forKey: reimbursableKey),
           let bills = try? JSONDecoder().decode([ReimbursableBill].self, from: data) {
            reimbursableBills = bills
        }
    }
}
