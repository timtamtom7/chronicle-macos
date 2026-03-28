import Foundation
import AppKit

// MARK: - Tax Export Service

final class TaxExportService {
    static let shared = TaxExportService()

    private init() {}

    // MARK: - Tax Report Generation

    struct TaxReport {
        let year: Int
        let totalDeductible: Decimal
        let totalReimbursable: Decimal
        let byCategory: [Category: Decimal]
        let byTag: [BusinessTag: Decimal]
        let bills: [Bill]
    }

    func generateTaxReport(year: Int, bills: [Bill]) -> TaxReport {
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

        var totalDeductible: Decimal = 0
        var totalReimbursable: Decimal = 0
        var byCategory: [Category: Decimal] = [:]
        var byTag: [BusinessTag: Decimal] = [:]
        var businessBills: [Bill] = []

        for bill in bills {
            guard bill.dueDate >= startDate && bill.dueDate <= endDate else { continue }

            if bill.isTaxDeductible {
                let amount = bill.amount
                byCategory[bill.category, default: 0] += amount
                byTag[bill.businessTag ?? .other, default: 0] += amount
                totalDeductible += amount
                businessBills.append(bill)
            }

            if bill.isReimbursable {
                totalReimbursable += bill.amount
            }
        }

        return TaxReport(
            year: year,
            totalDeductible: totalDeductible,
            totalReimbursable: totalReimbursable,
            byCategory: byCategory,
            byTag: byTag,
            bills: businessBills
        )
    }

    // MARK: - CSV Export

    func exportToCSV(report: TaxReport) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var csvLines: [String] = []
        // TurboTax/QuickBooks compatible header
        csvLines.append("date,vendor,amount,category,tax_deductible,reimbursable,tag,notes")

        for bill in report.bills {
            let date = dateFormatter.string(from: bill.dueDate)
            let vendor = bill.name.replacingOccurrences(of: "\"", with: "\"\"")
            let amount = String(format: "%.2f", NSDecimalNumber(decimal: bill.amount).doubleValue)
            let category = bill.category.rawValue.replacingOccurrences(of: "\"", with: "\"\"")
            let tag = (bill.businessTag ?? .other).rawValue.replacingOccurrences(of: "\"", with: "\"\"")
            let notes = (bill.notes ?? "").replacingOccurrences(of: "\"", with: "\"\"")

            let line = "\(date),\"\(vendor)\",\(amount),\(category),yes,\(bill.isReimbursable ? "yes" : "no"),\"\(tag)\",\"\(notes)\""
            csvLines.append(line)
        }

        let csv = csvLines.joined(separator: "\n")

        let exportDir = exportDirectory(for: report.year)
        let fileName = "Chronicle_TaxReport_\(report.year).csv"
        let fileURL = exportDir.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to export CSV: \(error)")
            return nil
        }
    }

    // MARK: - PDF Export

    func exportToPDF(report: TaxReport) -> URL? {
        let pageWidth: CGFloat = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let pdfMetaData = [
            kCGPDFContextCreator: "Chronicle",
            kCGPDFContextTitle: "Tax Report \(report.year)"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            var yPosition: CGFloat = margin

            // Header
            let headerFont = NSFont.boldSystemFont(ofSize: 18)
            let headerAttr: [NSAttributedString.Key: Any] = [.font: headerFont]
            let header = "Chronicle Tax Report — \(report.year)"
            header.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttr)
            yPosition += 30

            // Generated date
            let dateFont = NSFont.systemFont(ofSize: 10)
            let dateAttr: [NSAttributedString.Key: Any] = [.font: dateFont, .foregroundColor: NSColor.secondaryLabelColor]
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            let generatedDate = "Generated: \(dateFormatter.string(from: Date()))"
            generatedDate.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: dateAttr)
            yPosition += 25

            // Summary section
            let sectionFont = NSFont.boldSystemFont(ofSize: 13)
            let sectionAttr: [NSAttributedString.Key: Any] = [.font: sectionFont]
            let bodyFont = NSFont.systemFont(ofSize: 11)
            let bodyAttr: [NSAttributedString.Key: Any] = [.font: bodyFont]

            "Summary".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttr)
            yPosition += 20

            let currencyFormatter = NumberFormatter()
            currencyFormatter.numberStyle = .currency
            currencyFormatter.currencyCode = "USD"

            let deductibleStr = currencyFormatter.string(from: NSDecimalNumber(decimal: report.totalDeductible)) ?? "$0.00"
            let reimbursableStr = currencyFormatter.string(from: NSDecimalNumber(decimal: report.totalReimbursable)) ?? "$0.00"
            let countStr = "\(report.bills.count) bills"

            "Total Tax Deductible: \(deductibleStr)".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttr)
            yPosition += 16
            "Total Reimbursable: \(reimbursableStr)".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttr)
            yPosition += 16
            "Business Bills: \(countStr)".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttr)
            yPosition += 25

            // By Tag section
            "By Business Tag".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttr)
            yPosition += 20

            let sortedTags = report.byTag.sorted { $0.key.rawValue < $1.key.rawValue }
            for (tag, amount) in sortedTags {
                let tagStr = currencyFormatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
                "\(tag.rawValue): \(tagStr)".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttr)
                yPosition += 16
            }
            yPosition += 15

            // Bills table header
            if yPosition > pageHeight - 100 {
                context.beginPage()
                yPosition = margin
            }

            "Business Bills".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttr)
            yPosition += 20

            // Table header
            let col1 = "Date"
            let col2 = "Vendor"
            let col3 = "Amount"
            let col4 = "Category"
            let col5 = "Tag"

            let headerAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 9)]
            col1.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttrs)
            col2.draw(at: CGPoint(x: margin + 70, y: yPosition), withAttributes: headerAttrs)
            col3.draw(at: CGPoint(x: margin + 250, y: yPosition), withAttributes: headerAttrs)
            col4.draw(at: CGPoint(x: margin + 320, y: yPosition), withAttributes: headerAttrs)
            col5.draw(at: CGPoint(x: margin + 420, y: yPosition), withAttributes: headerAttrs)
            yPosition += 15

            // Separator line
            let linePath = NSBezierPath()
            linePath.move(to: CGPoint(x: margin, y: yPosition))
            linePath.line(to: CGPoint(x: pageWidth - margin, y: yPosition))
            NSColor.separatorColor.setStroke()
            linePath.stroke()
            yPosition += 5

            // Table rows
            for bill in report.bills {
                if yPosition > pageHeight - 60 {
                    context.beginPage()
                    yPosition = margin
                }

                let dateStr = dateFormatter.string(from: bill.dueDate)
                let amountStr = currencyFormatter.string(from: NSDecimalNumber(decimal: bill.amount)) ?? "$0.00"
                let tagStr = (bill.businessTag ?? .other).rawValue

                let rowAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9)]
                let truncatedName = bill.name.count > 30 ? String(bill.name.prefix(27)) + "..." : bill.name

                dateStr.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: rowAttrs)
                truncatedName.draw(at: CGPoint(x: margin + 70, y: yPosition), withAttributes: rowAttrs)
                amountStr.draw(at: CGPoint(x: margin + 250, y: yPosition), withAttributes: rowAttrs)
                bill.category.rawValue.draw(at: CGPoint(x: margin + 320, y: yPosition), withAttributes: rowAttrs)
                tagStr.draw(at: CGPoint(x: margin + 420, y: yPosition), withAttributes: rowAttrs)

                yPosition += 14
            }
        }

        let exportDir = exportDirectory(for: report.year)
        let fileName = "Chronicle_TaxReport_\(report.year).pdf"
        let fileURL = exportDir.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to export PDF: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private func exportDirectory(for year: Int) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Chronicle/Tax Exports/\(year)", isDirectory: true)
    }
}
