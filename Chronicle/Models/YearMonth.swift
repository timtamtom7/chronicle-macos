import Foundation

// MARK: - YearMonth

struct YearMonth: Hashable, Comparable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(date: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        self.year = components.year ?? calendar.component(.year, from: date)
        self.month = components.month ?? 1
    }

    var date: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    var startDate: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    var endDate: Date {
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    var displayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    var shortString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }

    func previous() -> YearMonth {
        if month == 1 {
            return YearMonth(year: year - 1, month: 12)
        } else {
            return YearMonth(year: year, month: month - 1)
        }
    }

    func next() -> YearMonth {
        if month == 12 {
            return YearMonth(year: year + 1, month: 1)
        } else {
            return YearMonth(year: year, month: month + 1)
        }
    }
}
