import Foundation
import Combine

@MainActor
final class BillStore: ObservableObject {
    static let shared = BillStore()

    @Published var bills: [Bill] = []
    @Published var upcomingBills: [Bill] = []
    @Published var searchText: String = ""
    @Published var templates: [BillTemplate] = []
    @Published var categoryBudgets: [CategoryBudget] = []
    @Published var isAccountantMode: Bool = false

    var baseCurrency: Currency {
        Currency(rawValue: UserDefaults.standard.string(forKey: "baseCurrency") ?? "USD") ?? .usd
    }

    private let db = DatabaseService.shared
    private let templateService = TemplateService.shared
    private let budgetService = BudgetService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadBills()
        loadTemplates()
        loadBudgets()
        Task { await ExchangeRateService.shared.fetchRatesIfNeeded() }

        // Observe accountant mode from BusinessService
        BusinessService.shared.$accountantMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.isAccountantMode = mode.isEnabled
            }
            .store(in: &cancellables)
    }

    // MARK: - Accountant Mode

    func lockToDateRange(start: Date, end: Date) {
        BusinessService.shared.enableAccountantMode(lockedRange: start...end)
    }

    var isLocked: Bool {
        isAccountantMode
    }

    var lockedDateRange: ClosedRange<Date>? {
        BusinessService.shared.accountantMode.lockedDateRange
    }

    /// Returns bills filtered by the locked date range if accountant mode is active
    var lockedBills: [Bill] {
        guard let range = lockedDateRange else { return bills }
        return bills.filter { range.contains($0.dueDate) }
    }

    // MARK: - Templates

    func loadTemplates() {
        templates = templateService.fetchAllTemplates()
    }

    func addTemplate(_ template: BillTemplate) {
        templateService.saveTemplate(template)
        loadTemplates()
    }

    func createTemplateFromBill(_ bill: Bill) {
        let template = BillTemplate.fromBill(bill)
        templateService.saveTemplate(template)
        loadTemplates()
    }

    func deleteTemplate(_ templateId: UUID) {
        templateService.deleteTemplate(templateId)
        loadTemplates()
    }

    func duplicateTemplate(_ template: BillTemplate) {
        let duplicate = templateService.duplicateTemplate(template)
        templateService.saveTemplate(duplicate)
        loadTemplates()
    }

    func createBillFromTemplate(_ template: BillTemplate, dueDate: Date = Date()) -> Bill {
        template.toBill(dueDate: dueDate)
    }

    func importTemplatesFromBills() {
        let suggested = templateService.suggestTemplateFromExistingBills(bills)
        for template in suggested {
            if !templates.contains(where: { $0.name == template.name && $0.category == template.category }) {
                templateService.saveTemplate(template)
            }
        }
        loadTemplates()
    }

    // MARK: - Budgets

    func loadBudgets() {
        categoryBudgets = budgetService.fetchAllBudgets()
    }

    func saveBudget(_ budget: CategoryBudget) {
        budgetService.saveBudget(budget)
        loadBudgets()
    }

    func deleteBudget(_ budgetId: UUID) {
        budgetService.deleteBudget(budgetId)
        loadBudgets()
    }

    func budget(for category: Category) -> CategoryBudget? {
        categoryBudgets.first { $0.category == category }
    }

    func spendingForCategory(_ category: Category) -> Decimal {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        return bills
            .filter { $0.category == category && $0.isPaid && $0.dueDate >= monthStart }
            .reduce(Decimal(0)) { total, bill in
                total + bill.amount
            }
    }

    func budgetStatus(for category: Category) -> (budget: CategoryBudget?, spent: Decimal, status: BudgetStatus) {
        let budget = self.budget(for: category)
        let spent = spendingForCategory(category)
        let status: BudgetStatus
        if let b = budget, b.isEnabled {
            status = budgetService.budgetStatus(for: b, spent: spent)
        } else {
            status = .underBudget
        }
        return (budget, spent, status)
    }

    var totalMonthlyBudget: Decimal {
        budgetService.monthlyBudget
    }

    var hasMonthlyBudget: Bool {
        budgetService.hasMonthlyBudget
    }

    func setMonthlyBudget(_ amount: Decimal) {
        let cents = Int(NSDecimalNumber(decimal: amount * 100).intValue)
        budgetService.monthlyBudgetCents = cents
    }

    var overallBudgetStatus: (spent: Decimal, limit: Decimal, status: BudgetStatus) {
        let spent = totalPaidThisMonth
        let limit = totalMonthlyBudget
        let status = budgetService.overallBudgetStatus(spent: spent, limit: limit)
        return (spent, limit, status)
    }

    // MARK: - Load

    func loadBills() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let fetchedBills: [Bill]
            do {
                fetchedBills = try await Task.detached(priority: .userInitiated) {
                    try DatabaseService.shared.fetchAllBills()
                }.value
            } catch {
                fetchedBills = []
            }

            let today = Date()
            let allBills = Self.computeNextDueDatesStatic(for: fetchedBills, from: today)

            await MainActor.run {
                self.bills = allBills
                self.upcomingBills = allBills.filter { !$0.isPaid }
                self.sortBillsIfNeeded()
                NotificationCenter.default.post(name: .billsDidChange, object: nil)
            }
        }
    }

    /// Compute next due dates for recurring bills — nonisolated so it can be called from detached tasks
    private static nonisolated func computeNextDueDatesStatic(for bills: [Bill], from today: Date) -> [Bill] {
        bills.map { bill in
            if bill.recurrence != .none {
                let nextDue = calculateNextDueDate(bill: bill, from: today)
                return Bill(
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
                    ownerId: bill.ownerId,
                    createdAt: bill.createdAt,
                    isTaxDeductible: bill.isTaxDeductible,
                    businessTag: bill.businessTag,
                    isReimbursable: bill.isReimbursable,
                    invoiceReference: bill.invoiceReference,
                    attachedInvoiceURL: bill.attachedInvoiceURL
                )
            }
            return bill
        }
    }

    private func updateUpcomingBills() {
        upcomingBills = bills.filter { !$0.isPaid }
    }

    private func sortBillsIfNeeded() {
        // Sort: unpaid first, then by due date
        bills.sort { b1, b2 in
            if b1.isPaid != b2.isPaid {
                return !b1.isPaid
            }
            return b1.dueDate < b2.dueDate
        }
    }

    // MARK: - CRUD

    func addBill(_ bill: Bill) {
        do {
            try db.insertBill(bill)
            loadBills()
            NotificationScheduler.shared.scheduleNotifications(for: bill)
            NotificationCenter.default.post(name: .billsDidChange, object: nil)
            
            // R17: Audit log
            AuditLogService.shared.log(
                .billCreated,
                entity: .bill(id: bill.id),
                details: ["name": bill.name, "amount": String(bill.amountCents)]
            )
        } catch {
            print("Failed to add bill: \(error)")
        }
    }

    func updateBill(_ bill: Bill) {
        do {
            // Capture old amount for audit
            let oldBill = bills.first(where: { $0.id == bill.id })
            
            try db.updateBill(bill)
            loadBills()
            NotificationScheduler.shared.scheduleNotifications(for: bill)
            NotificationCenter.default.post(name: .billsDidChange, object: nil)
            
            // R17: Audit log
            var details: [String: String] = ["name": bill.name]
            if let old = oldBill {
                details["oldAmount"] = String(old.amountCents)
            }
            details["newAmount"] = String(bill.amountCents)
            AuditLogService.shared.log(.billUpdated, entity: .bill(id: bill.id), details: details)
        } catch {
            print("Failed to update bill: \(error)")
        }
    }

    func deleteBill(_ billId: UUID) {
        do {
            let billName = bills.first(where: { $0.id == billId })?.name ?? "unknown"
            
            if let bill = bills.first(where: { $0.id == billId }) {
                NotificationScheduler.shared.cancelNotifications(for: bill)
            }
            try db.deleteBill(billId)
            loadBills()
            NotificationCenter.default.post(name: .billsDidChange, object: nil)
            
            // R17: Audit log
            AuditLogService.shared.log(
                .billDeleted,
                entity: .bill(id: billId),
                details: ["name": billName]
            )
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
            
            // R17: Audit log
            AuditLogService.shared.log(
                paid ? .billPaid : .billUnpaid,
                entity: .bill(id: bill.id),
                details: ["name": bill.name]
            )
        } catch {
            print("Failed to mark bill paid: \(error)")
        }
    }

    // MARK: - Filtered Views

    var filteredBills: [Bill] {
        guard !searchText.isEmpty else { return bills }
        return bills.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.invoiceReference?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
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
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return 0
        }

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
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return 0
        }

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

    /// Returns true if there are any payment records for this bill.
    func hasPaymentHistory(for bill: Bill) -> Bool {
        do {
            let records = try db.fetchPaymentRecords(for: bill.id)
            return !records.isEmpty
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

    // MARK: - Bill Ownership Views

    var householdBills: [Bill] {
        bills.filter { $0.ownerId == nil && billsSharedWithHousehold.contains($0.id) }
    }

    var personalBills: [Bill] {
        let sharedIds = billsSharedWithHousehold
        return bills.filter { bill in
            guard let ownerId = bill.ownerId else { return !sharedIds.contains(bill.id) }
            return ownerId == currentUserMemberId && !sharedIds.contains(bill.id)
        }
    }

    private var billsSharedWithHousehold: Set<UUID> {
        HouseholdService.shared.getSharedBillIds()
    }

    private var currentUserMemberId: UUID? {
        HouseholdService.shared.currentMember?.id
    }

    func bills(for ownerId: UUID) -> [Bill] {
        bills.filter { $0.ownerId == ownerId }
    }

    func billsSharedWithHousehold(ownerId: UUID) -> [Bill] {
        bills.filter { billsSharedWithHousehold.contains($0.id) && $0.ownerId == ownerId }
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
