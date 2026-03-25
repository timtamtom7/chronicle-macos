import Foundation
import AppKit

final class ExportService {
    static let shared = ExportService()

    private init() {}

    struct ExportMetadata: Codable {
        let appVersion: String
        let exportDate: Date
        let billCount: Int
        let paymentCount: Int
    }

    struct ChronicleExport: Codable {
        let metadata: ExportMetadata
        let bills: [Bill]
        let payments: [PaymentRecord]
    }

    func exportData() async throws -> URL {
        let bills = try DatabaseService.shared.fetchAllBills()
        let payments = try DatabaseService.shared.fetchAllPaymentRecords()

        let metadata = ExportMetadata(
            appVersion: "R8",
            exportDate: Date(),
            billCount: bills.count,
            paymentCount: payments.count
        )

        let export = ChronicleExport(metadata: metadata, bills: bills, payments: payments)

        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try jsonEncoder.encode(export)

        let tempDir = FileManager.default.temporaryDirectory
        let exportFileName = "Chronicle-\(formattedDate()).chronicle-export"
        let exportURL = tempDir.appendingPathComponent(exportFileName)

        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(at: exportURL)
        }
        try jsonData.write(to: exportURL)

        return exportURL
    }

    func exportToCSV(bills: [Bill], includePaid: Bool = true) -> URL? {
        var csvLines: [String] = []

        // Header
        csvLines.append("name,amount,currency,due_date,due_day,recurrence,category,is_paid,notes")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for bill in bills {
            if !includePaid && bill.isPaid { continue }

            let dueDate = dateFormatter.string(from: bill.dueDate)
            let notes = (bill.notes ?? "").replacingOccurrences(of: "\"", with: "\"\"")

            let line = "\"\(bill.name)\",\(bill.amountCents),\(bill.currency.rawValue),\(dueDate),\(bill.dueDay),\(bill.recurrence.rawValue),\(bill.category.rawValue),\(bill.isPaid ? "yes" : "no"),\"\(notes)\""
            csvLines.append(line)
        }

        let csvContent = csvLines.joined(separator: "\n")

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Chronicle-Bills-\(formattedDate()).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write CSV: \(error)")
            return nil
        }
    }

    func exportPaymentHistory(payments: [PaymentRecord], bills: [Bill]) -> URL? {
        var csvLines: [String] = []
        csvLines.append("bill_name,amount,paid_at,category")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        for payment in payments {
            let bill = bills.first { $0.id == payment.billId }
            let billName = bill?.name ?? "Unknown"
            let category = bill?.category.rawValue ?? "Other"
            let paidAt = dateFormatter.string(from: payment.paidAt)
            let line = "\"\(billName)\",\(payment.amountPaidCents),\(paidAt),\(category)"
            csvLines.append(line)
        }

        let csvContent = csvLines.joined(separator: "\n")

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Chronicle-Payments-\(formattedDate()).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write CSV: \(error)")
            return nil
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    func shareExport(at url: URL, from view: NSView? = nil) {
        let picker = NSSharingServicePicker(items: [url])
        if let targetView = view ?? NSApp.keyWindow?.contentView {
            picker.show(relativeTo: targetView.bounds, of: targetView, preferredEdge: .minY)
        }
    }
}

enum ExportError: Error {
    case exportFailed
}
