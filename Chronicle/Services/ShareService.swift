import Foundation
import AppKit

final class ShareService {
    static let shared = ShareService()

    private init() {}

    // MARK: - Text Summary

    func generateBillSummary(for bills: [Bill]) -> String {
        let active = bills.filter { !$0.isPaid }
        let paid = bills.filter { $0.isPaid }

        var text = "Chronicle Bill Summary\n"
        text += "========================\n\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"

        text += "Generated: \(dateFormatter.string(from: Date()))\n"
        text += "Total Bills: \(bills.count)\n"
        text += "Active: \(active.count) | Paid: \(paid.count)\n\n"

        if !active.isEmpty {
            text += "📋 UPCOMING BILLS\n"
            text += "-----------------\n"
            for bill in active.sorted(by: { $0.dueDate < $1.dueDate }) {
                text += "\(bill.name): \(bill.formattedAmount) (Due: \(dateFormatter.string(from: bill.dueDate)))\n"
            }
            text += "\n"
        }

        if !paid.isEmpty {
            text += "✅ PAID BILLS\n"
            text += "-------------\n"
            for bill in paid.prefix(10) {
                text += "\(bill.name): \(bill.formattedAmount)\n"
            }
            if paid.count > 10 {
                text += "... and \(paid.count - 10) more\n"
            }
        }

        return text
    }

    func generateMonthlySummary(bills: [Bill], month: Date) -> String {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!

        let monthBills = bills.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd }
        let paid = monthBills.filter { $0.isPaid }
        let unpaid = monthBills.filter { !$0.isPaid }

        let totalPaid = paid.reduce(Decimal(0)) { $0 + $1.amount }
        let totalDue = monthBills.reduce(Decimal(0)) { $0 + $1.amount }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"

        var text = "Chronicle Monthly Summary - \(dateFormatter.string(from: month))\n"
        text += "================================================\n\n"

        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = "USD"

        text += "Total Due: \(currencyFormatter.string(from: NSDecimalNumber(decimal: totalDue)) ?? "$0.00")\n"
        text += "Total Paid: \(currencyFormatter.string(from: NSDecimalNumber(decimal: totalPaid)) ?? "$0.00")\n"
        text += "Remaining: \(currencyFormatter.string(from: NSDecimalNumber(decimal: totalDue - totalPaid)) ?? "$0.00")\n\n"

        text += "Bills Breakdown:\n"
        for category in Category.allCases {
            let catBills = monthBills.filter { $0.category == category }
            if !catBills.isEmpty {
                let catTotal = catBills.reduce(Decimal(0)) { $0 + $1.amount }
                text += "  \(category.rawValue): \(currencyFormatter.string(from: NSDecimalNumber(decimal: catTotal)) ?? "$0.00") (\(catBills.count) bills)\n"
            }
        }

        return text
    }

    // MARK: - PDF Generation

    func generatePDF(for bills: [Bill], title: String = "Chronicle Bills") -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Chronicle-\(title.replacingOccurrences(of: " ", with: "-"))-\(formattedDate()).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)

        guard let consumer = CGDataConsumer(url: fileURL as CFURL) else { return nil }

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        let headerFont = NSFont.boldSystemFont(ofSize: 11)
        let bodyFont = NSFont.systemFont(ofSize: 11)
        let titleFont = NSFont.boldSystemFont(ofSize: 20)
        let dateFont = NSFont.systemFont(ofSize: 10)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"

        let rowDateFormatter = DateFormatter()
        rowDateFormatter.dateFormat = "MMM d, yyyy"

        let headers = ["Name", "Category", "Amount", "Due Date", "Status"]
        let columnWidths: [CGFloat] = [180, 100, 80, 80, 70]
        var xPositions: [CGFloat] = [margin]
        for i in 0..<columnWidths.count - 1 {
            xPositions.append(xPositions[i] + columnWidths[i])
        }

        let active = bills.filter { !$0.isPaid }.sorted { $0.dueDate < $1.dueDate }
        let paid = bills.filter { $0.isPaid }.sorted { $0.dueDate > $1.dueDate }
        let sortedBills = active + paid

        let rowHeight: CGFloat = 18
        let headerHeight: CGFloat = 20
        let linesPerPage = Int((pageHeight - 2 * margin - 100) / rowHeight)
        var currentY: CGFloat = pageHeight - margin

        func beginPage() {
            context.beginPDFPage(nil)
            currentY = pageHeight - margin
        }

        func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor) {
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            (text as NSString).draw(at: point, withAttributes: attributes)
        }

        beginPage()

        // Title
        drawText(title, at: CGPoint(x: margin, y: currentY - 24), font: titleFont, color: .black)
        currentY -= 35

        // Date
        drawText("Generated on \(dateFormatter.string(from: Date()))", at: CGPoint(x: margin, y: currentY), font: dateFont, color: .gray)
        currentY -= 25

        // Divider
        context.setStrokeColor(NSColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: currentY))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: currentY))
        context.strokePath()
        currentY -= 15

        // Header row
        NSColor(white: 0.93, alpha: 1.0).setFill()
        context.fill(CGRect(x: margin, y: currentY - headerHeight + 5, width: pageWidth - 2 * margin, height: headerHeight))
        currentY -= 5

        for (i, header) in headers.enumerated() {
            drawText(header, at: CGPoint(x: xPositions[i], y: currentY - 12), font: headerFont, color: .darkGray)
        }
        currentY -= headerHeight

        // Bill rows
        for (index, bill) in sortedBills.enumerated() {
            if currentY < margin + 80 {
                context.endPDFPage()
                beginPage()
            }

            if index % 2 == 0 {
                NSColor(white: 0.97, alpha: 1.0).setFill()
                context.fill(CGRect(x: margin, y: currentY - rowHeight + 3, width: pageWidth - 2 * margin, height: rowHeight))
            }

            let rowY = currentY - 12

            let textColor: NSColor = bill.isPaid ? .gray : .black
            drawText(bill.name, at: CGPoint(x: xPositions[0], y: rowY), font: bodyFont, color: textColor)
            drawText(bill.category.rawValue, at: CGPoint(x: xPositions[1], y: rowY), font: bodyFont, color: .gray)
            drawText(bill.formattedAmount, at: CGPoint(x: xPositions[2], y: rowY), font: bodyFont, color: textColor)
            drawText(rowDateFormatter.string(from: bill.dueDate), at: CGPoint(x: xPositions[3], y: rowY), font: bodyFont, color: .gray)

            let statusText = bill.isPaid ? "Paid" : bill.status().description
            let statusColor: NSColor = bill.isPaid ? NSColor(red: 0.35, green: 0.65, blue: 0.35, alpha: 1) : NSColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1)
            drawText(statusText, at: CGPoint(x: xPositions[4], y: rowY), font: bodyFont, color: statusColor)

            currentY -= rowHeight
        }

        // Summary
        currentY -= 15
        context.setStrokeColor(NSColor.lightGray.cgColor)
        context.move(to: CGPoint(x: margin, y: currentY))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: currentY))
        context.strokePath()
        currentY -= 20

        let totalActive = active.reduce(Decimal(0)) { $0 + $1.amount }
        let totalPaidAmount = paid.reduce(Decimal(0)) { $0 + $1.amount }

        let summaryFont = NSFont.boldSystemFont(ofSize: 11)
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency

        let summaryLines = [
            "Total Active Bills: \(active.count)",
            "Total Amount Due: \(currencyFormatter.string(from: NSDecimalNumber(decimal: totalActive)) ?? "$0.00")",
            "Total Paid: \(currencyFormatter.string(from: NSDecimalNumber(decimal: totalPaidAmount)) ?? "$0.00")"
        ]

        for line in summaryLines {
            drawText(line, at: CGPoint(x: margin, y: currentY), font: summaryFont, color: .black)
            currentY -= 16
        }

        context.endPDFPage()
        context.closePDF()

        return fileURL
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    func shareItems(for bills: [Bill], from view: NSView? = nil) {
        let text = generateBillSummary(for: bills)
        let picker = NSSharingServicePicker(items: [text])
        if let targetView = view ?? NSApp.keyWindow?.contentView {
            picker.show(relativeTo: targetView.bounds, of: targetView, preferredEdge: .minY)
        }
    }

    func sharePDF(for bills: [Bill], title: String = "Bills", from view: NSView? = nil) {
        guard let pdfURL = generatePDF(for: bills, title: title) else { return }
        let picker = NSSharingServicePicker(items: [pdfURL])
        if let targetView = view ?? NSApp.keyWindow?.contentView {
            picker.show(relativeTo: targetView.bounds, of: targetView, preferredEdge: .minY)
        }
    }
}

extension BillStatus {
    var description: String {
        switch self {
        case .dueToday: return "Due Today"
        case .dueSoon: return "Due Soon"
        case .upcoming: return "Upcoming"
        case .overdue: return "Overdue"
        case .paid: return "Paid"
        }
    }
}
