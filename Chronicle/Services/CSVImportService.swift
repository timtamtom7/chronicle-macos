import Foundation

final class CSVImportService {
    static let shared = CSVImportService()

    private init() {}

    struct ImportResult {
        let successCount: Int
        let failedCount: Int
        let errors: [String]
        let importedBills: [Bill]
    }

    func parseCSV(_ content: String) -> ImportResult {
        var bills: [Bill] = []
        var errors: [String] = []

        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count > 1 else {
            return ImportResult(successCount: 0, failedCount: 0, errors: ["File is empty or has no data rows"], importedBills: [])
        }

        let headers = parseCSVLine(lines[0]).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        let nameIdx = headers.firstIndex(of: "name") ?? headers.firstIndex(of: "bill name") ?? headers.firstIndex(of: "title")
        let amountIdx = headers.firstIndex(of: "amount") ?? headers.firstIndex(of: "amount cents") ?? headers.firstIndex(of: "amount_cents")
        let currencyIdx = headers.firstIndex(of: "currency") ?? headers.firstIndex(of: "currency code")
        let dueDayIdx = headers.firstIndex(of: "due day") ?? headers.firstIndex(of: "due_day") ?? headers.firstIndex(of: "day")
        let dueDateIdx = headers.firstIndex(of: "due date") ?? headers.firstIndex(of: "due_date") ?? headers.firstIndex(of: "date")
        let recurrenceIdx = headers.firstIndex(of: "recurrence") ?? headers.firstIndex(of: "frequency")
        let categoryIdx = headers.firstIndex(of: "category")
        let notesIdx = headers.firstIndex(of: "notes") ?? headers.firstIndex(of: "description")

        guard nameIdx != nil && (amountIdx != nil || dueDateIdx != nil) else {
            return ImportResult(
                successCount: 0,
                failedCount: 0,
                errors: ["CSV must have at least 'name' and 'amount' or 'due_date' columns"],
                importedBills: []
            )
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let dateFormatterAlt = DateFormatter()
        dateFormatterAlt.dateFormat = "MM/dd/yyyy"

        for (lineNum, line) in lines.dropFirst().enumerated() {
            let fields = parseCSVLine(line)

            guard fields.count > 0 else { continue }

            let name = nameIdx.flatMap { $0 < fields.count ? fields[$0] : nil }?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !name.isEmpty else {
                errors.append("Line \(lineNum + 2): Missing name, skipping")
                continue
            }

            var amountCents = 0
            if let idx = amountIdx, idx < fields.count {
                let amountStr = fields[idx].trimmingCharacters(in: .whitespaces)
                if let cents = parseAmountToCents(amountStr) {
                    amountCents = cents
                }
            }

            let currency: Currency
            if let idx = currencyIdx, idx < fields.count {
                currency = Currency(rawValue: fields[idx].uppercased().trimmingCharacters(in: .whitespaces)) ?? .usd
            } else {
                currency = .usd
            }

            var dueDay = 1
            if let idx = dueDayIdx, idx < fields.count {
                dueDay = Int(fields[idx].trimmingCharacters(in: .whitespaces)) ?? 1
            }

            var dueDate = Date()
            if let idx = dueDateIdx, idx < fields.count {
                let dateStr = fields[idx].trimmingCharacters(in: .whitespaces)
                if let parsed = dateFormatter.date(from: dateStr) {
                    dueDate = parsed
                } else if let parsed = dateFormatterAlt.date(from: dateStr) {
                    dueDate = parsed
                } else if let day = Int(dateStr), day > 0 && day <= 31 {
                    dueDay = day
                    var components = Calendar.current.dateComponents([.year, .month], from: Date())
                    components.day = day
                    dueDate = Calendar.current.date(from: components) ?? Date()
                }
            }

            let recurrence: Recurrence
            if let idx = recurrenceIdx, idx < fields.count {
                recurrence = parseRecurrence(fields[idx].trimmingCharacters(in: .whitespaces))
            } else {
                recurrence = .monthly
            }

            let category: Category
            if let idx = categoryIdx, idx < fields.count {
                category = parseCategory(fields[idx].trimmingCharacters(in: .whitespaces))
            } else {
                category = .other
            }

            let notes = notesIdx.flatMap { $0 < fields.count ? fields[$0] : nil }?.trimmingCharacters(in: .whitespaces)

            let bill = Bill(
                id: UUID(),
                name: name,
                amountCents: amountCents,
                currency: currency,
                dueDay: dueDay,
                dueDate: dueDate,
                recurrence: recurrence,
                category: category,
                notes: notes?.isEmpty == true ? nil : notes,
                reminderTimings: [],
                autoMarkPaid: false,
                isActive: true,
                isPaid: false,
                createdAt: Date()
            )

            bills.append(bill)
        }

        return ImportResult(
            successCount: bills.count,
            failedCount: errors.count,
            errors: errors,
            importedBills: bills
        )
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)

        return fields.map { $0.replacingOccurrences(of: "\"", with: "") }
    }

    private func parseAmountToCents(_ str: String) -> Int? {
        let cleaned = str.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        guard let amount = Decimal(string: cleaned) else { return nil }
        return Int(NSDecimalNumber(decimal: amount * 100).intValue)
    }

    private func parseRecurrence(_ str: String) -> Recurrence {
        let lower = str.lowercased()
        switch lower {
        case "weekly", "week": return .weekly
        case "biweekly", "bi-weekly", "fortnightly": return .biweekly
        case "monthly", "month": return .monthly
        case "quarterly", "quarter": return .quarterly
        case "semi-annual", "semiannual", "semiyearly": return .semiAnnual
        case "annual", "yearly", "year": return .annual
        default: return .monthly
        }
    }

    private func parseCategory(_ str: String) -> Category {
        let lower = str.lowercased()
        for cat in Category.allCases {
            if cat.rawValue.lowercased().contains(lower) || lower.contains(cat.rawValue.lowercased()) {
                return cat
            }
        }
        return .other
    }
}
