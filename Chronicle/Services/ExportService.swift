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
            appVersion: "R5",
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
