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

        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = "USD"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let displayDateFormatter = DateFormatter()
        displayDateFormatter.dateStyle = .long

        // Create a view to render the PDF
        let view = TaxReportView(
            report: report,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            margin: margin,
            currencyFormatter: currencyFormatter,
            dateFormatter: dateFormatter,
            displayDateFormatter: displayDateFormatter
        )

        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: pageWidth, height: pageHeight)
        printInfo.topMargin = margin
        printInfo.bottomMargin = margin
        printInfo.leftMargin = margin
        printInfo.rightMargin = margin
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = false

        let viewSize = view.frame.size
        view.frame = NSRect(x: 0, y: 0, width: viewSize.width, height: viewSize.height)

        let pdfData = NSMutableData()
        var mediaBox = NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        let pageCount = view.calculatePageCount(width: pageWidth, height: pageHeight, margin: margin)

        for pageIndex in 0..<pageCount {
            var pageRect = NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
            pdfContext.beginPage(mediaBox: &pageRect)

            NSGraphicsContext.saveGraphicsState()
            let ctx = NSGraphicsContext(cgContext: pdfContext, flipped: false)
            NSGraphicsContext.current = ctx

            view.drawPage(pageIndex, width: pageWidth, height: pageHeight, margin: margin)

            NSGraphicsContext.restoreGraphicsState()
            pdfContext.endPage()
        }

        pdfContext.closePDF()

        let exportDir = exportDirectory(for: report.year)
        let fileName = "Chronicle_TaxReport_\(report.year).pdf"
        let fileURL = exportDir.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            try pdfData.write(to: fileURL, options: .atomic)
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

// MARK: - Tax Report PDF View

final class TaxReportView: NSView {
    let report: TaxExportService.TaxReport
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let margin: CGFloat
    let currencyFormatter: NumberFormatter
    let dateFormatter: DateFormatter
    let displayDateFormatter: DateFormatter

    init(report: TaxExportService.TaxReport, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat,
         currencyFormatter: NumberFormatter, dateFormatter: DateFormatter, displayDateFormatter: DateFormatter) {
        self.report = report
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.margin = margin
        self.currencyFormatter = currencyFormatter
        self.dateFormatter = dateFormatter
        self.displayDateFormatter = displayDateFormatter
        super.init(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight * 2))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func calculatePageCount(width: CGFloat, height: CGFloat, margin: CGFloat) -> Int {
        // Rough estimate: header ~100pt, summary ~100pt, tag section ~200pt, table header ~35pt, rows ~14pt each
        let headerHeight: CGFloat = 100
        let summaryHeight: CGFloat = 100
        let tagSectionHeight: CGFloat = CGFloat(report.byTag.count) * 16 + 40
        let tableHeaderHeight: CGFloat = 35
        let rowsHeight: CGFloat = CGFloat(report.bills.count) * 14

        let pageContentHeight = height - 2 * margin
        var total = headerHeight + summaryHeight + tagSectionHeight + tableHeaderHeight + rowsHeight
        // Extra for page breaks
        total += pageContentHeight // at most 2 pages

        return max(1, Int(total / pageContentHeight) + 1)
    }

    func drawPage(_ pageIndex: Int, width: CGFloat, height: CGFloat, margin: CGFloat) {
        let contentWidth = width - 2 * margin
        var y: CGFloat = height - margin

        let headerFont = NSFont.boldSystemFont(ofSize: 18)
        let sectionFont = NSFont.boldSystemFont(ofSize: 13)
        let bodyFont = NSFont.systemFont(ofSize: 11)
        let captionFont = NSFont.systemFont(ofSize: 10)
        let tableHeaderFont = NSFont.boldSystemFont(ofSize: 9)
        let tableFont = NSFont.systemFont(ofSize: 9)

        // Header
        let header = "Chronicle Tax Report — \(report.year)"
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont]
        header.draw(at: NSPoint(x: margin, y: y - 18), withAttributes: headerAttrs)
        y -= 30

        // Generated date
        let generatedDate = "Generated: \(displayDateFormatter.string(from: Date()))"
        let dateAttrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: NSColor.secondaryLabelColor]
        generatedDate.draw(at: NSPoint(x: margin, y: y - 10), withAttributes: dateAttrs)
        y -= 25

        // Summary
        let sectionAttrs: [NSAttributedString.Key: Any] = [.font: sectionFont]
        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont]

        "Summary".draw(at: NSPoint(x: margin, y: y), withAttributes: sectionAttrs)
        y -= 20

        let deductibleStr = currencyFormatter.string(from: NSDecimalNumber(decimal: report.totalDeductible)) ?? "$0.00"
        let reimbursableStr = currencyFormatter.string(from: NSDecimalNumber(decimal: report.totalReimbursable)) ?? "$0.00"
        let countStr = "\(report.bills.count) bills"

        "\u{2022} Total Tax Deductible: \(deductibleStr)".draw(at: NSPoint(x: margin + 10, y: y), withAttributes: bodyAttrs)
        y -= 16
        "\u{2022} Total Reimbursable: \(reimbursableStr)".draw(at: NSPoint(x: margin + 10, y: y), withAttributes: bodyAttrs)
        y -= 16
        "\u{2022} Business Bills: \(countStr)".draw(at: NSPoint(x: margin + 10, y: y), withAttributes: bodyAttrs)
        y -= 25

        // By Tag
        "By Business Tag".draw(at: NSPoint(x: margin, y: y), withAttributes: sectionAttrs)
        y -= 20

        let sortedTags = report.byTag.sorted { $0.key.rawValue < $1.key.rawValue }
        for (tag, amount) in sortedTags {
            let tagStr = currencyFormatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
            "\u{2022} \(tag.rawValue): \(tagStr)".draw(at: NSPoint(x: margin + 10, y: y), withAttributes: bodyAttrs)
            y -= 16
        }
        y -= 15

        // Bills table header
        if y > 60 {
            "Business Bills".draw(at: NSPoint(x: margin, y: y), withAttributes: sectionAttrs)
            y -= 20

            let tableHeaderAttrs: [NSAttributedString.Key: Any] = [.font: tableHeaderFont]
            "Date".draw(at: NSPoint(x: margin, y: y), withAttributes: tableHeaderAttrs)
            "Vendor".draw(at: NSPoint(x: margin + 70, y: y), withAttributes: tableHeaderAttrs)
            "Amount".draw(at: NSPoint(x: margin + 250, y: y), withAttributes: tableHeaderAttrs)
            "Category".draw(at: NSPoint(x: margin + 320, y: y), withAttributes: tableHeaderAttrs)
            "Tag".draw(at: NSPoint(x: margin + 420, y: y), withAttributes: tableHeaderAttrs)
            y -= 15

            // Separator
            let path = NSBezierPath()
            path.move(to: NSPoint(x: margin, y: y))
            path.line(to: NSPoint(x: width - margin, y: y))
            NSColor.separatorColor.setStroke()
            path.lineWidth = 0.5
            path.stroke()
            y -= 5

            // Table rows (page 0)
            let rowAttrs: [NSAttributedString.Key: Any] = [.font: tableFont]
            let rowsPerPage = Int((height - 2 * margin - 100) / 14)
            let startRow = pageIndex * rowsPerPage
            let endRow = min(startRow + rowsPerPage, report.bills.count)

            for i in startRow..<endRow {
                if i >= report.bills.count { break }
                let bill = report.bills[i]

                let dateStr = dateFormatter.string(from: bill.dueDate)
                let amountStr = currencyFormatter.string(from: NSDecimalNumber(decimal: bill.amount)) ?? "$0.00"
                let tagStr = (bill.businessTag ?? .other).rawValue
                let truncatedName = bill.name.count > 30 ? String(bill.name.prefix(27)) + "..." : bill.name

                dateStr.draw(at: NSPoint(x: margin, y: y), withAttributes: rowAttrs)
                truncatedName.draw(at: NSPoint(x: margin + 70, y: y), withAttributes: rowAttrs)
                amountStr.draw(at: NSPoint(x: margin + 250, y: y), withAttributes: rowAttrs)
                bill.category.rawValue.draw(at: NSPoint(x: margin + 320, y: y), withAttributes: rowAttrs)
                tagStr.draw(at: NSPoint(x: margin + 420, y: y), withAttributes: rowAttrs)
                y -= 14
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
