import Foundation
import Combine

@MainActor
final class BillStore: ObservableObject {
    @Published var bills: [Bill] = []
    @Published var upcomingBills: [Bill] = []
    @Published var searchText: String = ""

    var baseCurrency: Currency {
        Currency(rawValue: UserDefaults.standard.string(forKey: "baseCurrency") ?? "USD") ?? .usd
    }

    private let db = DatabaseService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadBills()
        Task { await ExchangeRateService.shared.fetchRatesIfNeeded() }
    }

    // MARK: - Load

    func loadBills() {
        do {
            var allBills = try db.fetchAllBills()

            let today = Date()
            allBills = allBills.map { bill in
                if bill.recurrence != .none {
                    let nextDue = calculateNextDueDate(bill: bill, from: today)
                    var updatedBill = bill
                    updatedBill = Bill(
                        id: bill.id,
                        name: bill.name,
                        amountCents: bill.amountCents,
                        currency: bill.currency,
                        dueDay: bill.dueDay,
                        dueDate: nextDue,
                        recurrence: bill.recurrence,
                        category: bill.category,
                        notes: bill.notes,
                        reminderTimings: bill.reminderTimings,
                        autoMarkPaid: bill.autoMarkPaid,
                        isActive: bill.isActive,
                        isPaid: bill.isPaid,
                        createdAt: bill.createdAt
                    )
                    return updatedBill
                }
                return bill
            }

            allBills.sort { b1, b2 in
                if b1.isPaid != b2.isPaid {
                    return !b1.isPaid
                }
                return b1.dueDate < b2.dueDate
            }

            self.bills = allBills
            self.upcomingBills = allBills.filter { !$0.isPaid }
        } catch {
            print("Failed to load bills: \(error)")
        }
    }

    // MARK: - CRUD

    func addBill(_ bill: Bill) {
        do {
            try db.insertBill(bill)
            loadBills()
            NotificationScheduler.shared.scheduleNotifications(for: bill)
            NotificationCenter.default.post(name: .billsDidChange, object: nil)
        } catch {
            print("Failed to add bill: \(error)")
        }
    }

    func updateBill(_ bill: Bill) {
        do {
            try db.updateBill(bill)
            loadBills()
            NotificationScheduler.shared.scheduleNotifications(for: bill)
            NotificationCenter.default.post(name: .billsDidChange, object: nil)
        } catch {
            print("Failed to update bill: \(error)")
        }
    }

    func deleteBill(_ billId: UUID) {
        do {
            if let bill = bills.first(where: { $0.id == billId }) {
                NotificationScheduler.shared.cancelNotifications(for: bill)
            }
            try db.deleteBill(billId)
            loadBills()
            NotificationCenter.default.post(name: .billsDidChange, object: nil)
        } catch {
            print("Failed to delete bill: \(error)")
        }
    }

    func markPaid(_ bill: Bill, paid: Bool) {
        do {
            try db.markBillPaid(bill.id, paid: paid)
            if paid {
                NotificationScheduler.shared.cancelNotifications(for: bill)
            } else {
                NotificationScheduler.shared.scheduleNotifications(for: bill)
            }
            loadBills()
            NotificationCenter.default.post(name: .billsDidChange, object: nil)
        } catch {
            print("Failed to mark bill paid: \(error)")
        }
    }

    // MARK: - Filtered Views

    var filteredBills: [Bill] {
        guard !searchText.isEmpty else { return bills }
        return bills.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var dueThisWeek: [Bill] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: today) else { return [] }

        return filteredBills.filter { bill in
            !bill.isPaid && bill.dueDate >= today && bill.dueDate < weekEnd
        }
    }

    var upcomingBillsList: [Bill] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: today) else { return [] }

        return filteredBills.filter { bill in
            !bill.isPaid && bill.dueDate >= weekEnd
        }
    }

    var pastDue: [Bill] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return filteredBills.filter { bill in
            !bill.isPaid && bill.dueDate < today
        }
    }

    var paidBills: [Bill] {
        return filteredBills.filter { $0.isPaid }
    }

    // MARK: - Monthly Overview (multi-currency aware)

    private var exchangeRates: [String: Double] {
        ExchangeRateService.shared.rates
    }

    var totalDueThisMonth: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!

        return bills
            .filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd && !$0.isPaid }
            .reduce(Decimal(0)) { total, bill in
                if let converted = bill.formattedAmountInBaseCurrency(baseCurrency: baseCurrency, rates: exchangeRates),
                   let value = parseCurrencyValue(converted) {
                    return total + value
                }
                return total + bill.amount
            }
    }

    var totalPaidThisMonth: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!

        return bills
            .filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd && $0.isPaid }
            .reduce(Decimal(0)) { total, bill in
                if let converted = bill.formattedAmountInBaseCurrency(baseCurrency: baseCurrency, rates: exchangeRates),
                   let value = parseCurrencyValue(converted) {
                    return total + value
                }
                return total + bill.amount
            }
    }

    private func parseCurrencyValue(_ formatted: String) -> Decimal? {
        let cleaned = formatted.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
        let normalized = cleaned.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    var totalRemainingThisMonth: Decimal {
        totalDueThisMonth - totalPaidThisMonth
    }

    // MARK: - Payment History

    func paymentRecords(for bill: Bill) -> [PaymentRecord] {
        do {
            return try db.fetchPaymentRecords(for: bill.id)
        } catch {
            print("Failed to fetch payment records: \(error)")
            return []
        }
    }

    func allPaymentRecords() -> [PaymentRecord] {
        do {
            return try db.fetchAllPaymentRecords()
        } catch {
            print("Failed to fetch all payment records: \(error)")
            return []
        }
    }

    func paymentRecordsGroupedByMonth() -> [YearMonth: [PaymentRecord]] {
        do {
            return try db.fetchPaymentRecordsGroupedByMonth()
        } catch {
            print("Failed to group payment records: \(error)")
            return [:]
        }
    }

    func deletePaymentRecord(_ record: PaymentRecord) {
        do {
            try db.deletePaymentRecord(record.id)
            loadBills()
        } catch {
            print("Failed to delete payment record: \(error)")
        }
    }

    func wasPaidThisPeriod(for bill: Bill) -> Bool {
        let currentMonth = YearMonth(date: Date())
        do {
            return try db.wasPaidThisPeriod(for: bill, in: currentMonth)
        } catch {
            return false
        }
    }

    // MARK: - Monthly Stats

    func totalSpentThisMonth() -> Decimal {
        totalPaidThisMonth
    }

    func totalDueThisMonthValue() -> Decimal {
        totalDueThisMonth
    }

    func spendingByCategory(for period: YearMonth) -> [Category: Decimal] {
        let records = doGetPaymentRecords(for: period)
        var result: [Category: Decimal] = [:]

        for record in records {
            if let bill = bills.first(where: { $0.id == record.billId }) {
                result[bill.category, default: 0] += record.amount
            }
        }

        return result
    }

    private func doGetPaymentRecords(for period: YearMonth) -> [PaymentRecord] {
        do {
            return try db.fetchPaymentRecords(forMonth: period)
        } catch {
            return []
        }
    }

    func monthlyTrend(months: Int = 6) -> [YearMonth: Decimal] {
        var result: [YearMonth: Decimal] = [:]
        var current = YearMonth(date: Date())

        for _ in 0..<months {
            let spent = spendingByCategory(for: current).values.reduce(Decimal(0), +)
            result[current] = spent
            current = current.previous()
        }

        return result
    }

    func bills(for category: Category) -> [Bill] {
        return bills.filter { $0.category == category && !$0.isPaid }
    }

    func billsPaidInMonth(_ period: YearMonth) -> [PaymentRecord] {
        doGetPaymentRecords(for: period)
    }

    func undoPayment(record: PaymentRecord) {
        do {
            try db.deletePaymentRecord(record.id)
            loadBills()
        } catch {
            print("Failed to undo payment: \(error)")
        }
    }
}
