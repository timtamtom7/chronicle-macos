import Foundation
import Combine

@MainActor
final class BillStore: ObservableObject {
    @Published var bills: [Bill] = []
    @Published var upcomingBills: [Bill] = []
    @Published var searchText: String = ""

    private let db = DatabaseService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadBills()
    }

    // MARK: - Load

    func loadBills() {
        do {
            var allBills = try db.fetchAllBills()

            // Recalculate due dates for recurring bills
            let today = Date()
            allBills = allBills.map { bill in
                var mutableBill = bill
                if bill.recurrence != .none {
                    let nextDue = calculateNextDueDate(bill: bill, from: today)
                    mutableBill = Bill(
                        id: bill.id,
                        name: bill.name,
                        amountCents: bill.amountCents,
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
                }
                return mutableBill
            }

            // Sort: unpaid first, then by due date
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
            // Schedule notifications for the new bill
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
            // Reschedule notifications (cancel existing, schedule new)
            NotificationScheduler.shared.scheduleNotifications(for: bill)
            NotificationCenter.default.post(name: .billsDidChange, object: nil)
        } catch {
            print("Failed to update bill: \(error)")
        }
    }

    func deleteBill(_ billId: UUID) {
        do {
            // Cancel notifications before deleting
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
                // Cancel notifications when marked paid
                NotificationScheduler.shared.cancelNotifications(for: bill)
            } else {
                // Reschedule if unmarking
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

    // MARK: - Monthly Overview

    var totalDueThisMonth: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!

        return bills
            .filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd && !$0.isPaid }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    var totalPaidThisMonth: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!

        return bills
            .filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd && $0.isPaid }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    var totalRemainingThisMonth: Decimal {
        totalDueThisMonth - totalPaidThisMonth
    }
}
