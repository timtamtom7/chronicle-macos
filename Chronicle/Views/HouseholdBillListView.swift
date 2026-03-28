import SwiftUI
import AppKit

// MARK: - Household Bill List View

struct HouseholdBillListView: View {
    @EnvironmentObject var billStore: BillStore
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var householdService = HouseholdService.shared
    @State private var selectedFilter: BillListFilter = .myBills
    @State private var searchText = ""
    @State private var showDeleteAlert = false
    @State private var billToDelete: Bill?
    @State private var activeSheet: SheetDestination?

    enum BillListFilter: String, CaseIterable {
        case myBills = "My Bills"
        case householdBills = "Household Bills"
        case all = "All"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter toggle
            if householdService.household != nil {
                filterToggleBar
                Divider()
            }

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(filteredBills) { bill in
                        householdBillRow(bill)
                    }

                    if filteredBills.isEmpty {
                        emptyStateView
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .alert("Delete Bill?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let bill = billToDelete {
                    billStore.deleteBill(bill.id)
                }
            }
        } message: {
            if let bill = billToDelete {
                Text("Are you sure you want to delete \"\(bill.name)\"? This cannot be undone.")
            }
        }
    }

    // MARK: - Filter Toggle

    private var filterToggleBar: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textTertiary)
                TextField("Search bills...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .frame(width: 160)
                    .accessibilityLabel("Search bills")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.surfaceSecondary)
            .cornerRadius(Theme.radiusSmall)

            Spacer()

            // Filter segmented control
            if householdService.household != nil {
                HStack(spacing: 0) {
                    ForEach(BillListFilter.allCases, id: \.self) { filter in
                        Button(action: { selectedFilter = filter }) {
                            Text(filter.rawValue)
                                .font(.caption)
                                .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                .foregroundColor(selectedFilter == filter ? Theme.textOnAccent : Theme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedFilter == filter ? Theme.accent : Color.clear)
                                .cornerRadius(Theme.radiusSmall)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Theme.surfaceSecondary)
                .cornerRadius(Theme.radiusMedium)
            }

            // Add button
            Button(action: { activeSheet = .addBill }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Add")
                }
                .font(.footnote)
                .foregroundColor(Theme.textOnAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.accent)
                .cornerRadius(Theme.radiusSmall)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add new bill")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surface)
    }

    // MARK: - Bill Row

    private func householdBillRow(_ bill: Bill) -> some View {
        let isHousehold = isHouseholdBill(bill)
        let household = householdService.household
        let owner = household?.members.first { $0.id == getOwnerId(for: bill) }

        return HStack(spacing: 12) {
            // Checkbox
            Button(action: { billStore.markPaid(bill, paid: !bill.isPaid) }) {
                Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(bill.isPaid ? Theme.success : Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(bill.isPaid ? "Mark as unpaid" : "Mark as paid")

            // Left border
            RoundedRectangle(cornerRadius: 2)
                .fill(categoryColor(for: bill))
                .frame(width: 3)
                .accessibilityHidden(true)

            // Bill info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(bill.name)
                        .font(.callout)
                        .foregroundColor(bill.isPaid ? Theme.textTertiary : Theme.textPrimary)
                        .strikethrough(bill.isPaid)

                    // Household badge
                    if isHousehold, let owner = owner {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color(hex: owner.colorHex))
                                .frame(width: 5, height: 5)
                            Text("Paid by \(owner.name)")
                                .font(.caption2)
                                .foregroundColor(Theme.textTertiary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.surfaceSecondary)
                        .cornerRadius(Theme.radiusSmall)
                    }
                }

                HStack(spacing: 4) {
                    Text(bill.formattedAmount)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textSecondary)

                    Text("·")
                        .foregroundColor(Theme.textTertiary)

                    Text(bill.recurrence.shortName)
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)

                    Text("·")
                        .foregroundColor(Theme.textTertiary)

                    Image(systemName: bill.category.icon)
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)

                    Text(bill.category.rawValue)
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)

                    // Split breakdown
                    if let split = householdService.getSplit(for: bill.id) {
                        Text("·")
                            .foregroundColor(Theme.textTertiary)
                        Text("\(split.splits.count) way")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            Spacer()

            // Due date
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedDueDate(bill))
                    .font(.caption)
                    .foregroundColor(dueDateColor(for: bill))

                if bill.recurrence != .none {
                    Text("Next: \(formattedNextDue(bill))")
                        .font(.caption2)
                        .foregroundColor(Theme.textTertiary)
                }
            }

            // Actions
            HStack(spacing: 4) {
                Button(action: { activeSheet = .editBill(bill) }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .opacity(0.6)
                .accessibilityLabel("Edit \(bill.name)")

                Button(action: {
                    billToDelete = bill
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.danger)
                }
                .buttonStyle(.plain)
                .opacity(0.6)
                .accessibilityLabel("Delete \(bill.name)")
            }
        }
        .padding(12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
        .sheet(item: $activeSheet) { destination in
            switch destination {
            case .addBill:
                AddBillSheet()
            case .editBill(let bill):
                AddBillSheet(editingBill: bill)
            case .viewInvoice(let bill):
                if let url = bill.attachedInvoiceURL {
                    InvoicePreviewView(invoiceURL: url)
                }
            case .viewReceipt(let bill):
                if let url = bill.receiptURL {
                    InvoicePreviewView(invoiceURL: url)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 40))
                .foregroundColor(Theme.textTertiary)

            Text(emptyStateMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            if selectedFilter == .myBills && householdService.household != nil {
                Button("Switch to All Bills") {
                    selectedFilter = .all
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var emptyStateIcon: String {
        switch selectedFilter {
        case .myBills: return "person.crop.circle.badge.questionmark"
        case .householdBills: return "house.fill"
        case .all: return "doc.text.magnifyingglass"
        }
    }

    private var emptyStateMessage: String {
        switch selectedFilter {
        case .myBills: return "No personal bills this month"
        case .householdBills: return "No household bills this month"
        case .all: return "No bills yet"
        }
    }

    // MARK: - Helpers

    private var filteredBills: [Bill] {
        var bills = billStore.bills

        // Filter by household
        if householdService.household != nil {
            switch selectedFilter {
            case .myBills:
                bills = bills.filter { !isHouseholdBill($0) }
            case .householdBills:
                bills = bills.filter { isHouseholdBill($0) }
            case .all:
                break
            }
        }

        // Search filter
        if !searchText.isEmpty {
            bills = bills.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Sort by due date
        bills.sort { $0.dueDate < $1.dueDate }

        return bills
    }

    private func isHouseholdBill(_ bill: Bill) -> Bool {
        guard let household = householdService.household else { return false }
        return household.members.count > 1
    }

    private func getOwnerId(for bill: Bill) -> UUID {
        guard let household = householdService.household else {
            return HouseholdMember.currentUserId
        }
        return household.members.first?.id ?? HouseholdMember.currentUserId
    }

    private func categoryColor(for bill: Bill) -> Color {
        if bill.isPaid { return Theme.success }
        switch bill.status() {
        case .dueToday, .dueSoon: return Theme.accent
        case .upcoming: return ThemeCategoryColors.map[bill.category] ?? Theme.border
        case .overdue: return Theme.danger
        case .paid: return Theme.success
        }
    }

    private func dueDateColor(for bill: Bill) -> Color {
        switch bill.status() {
        case .dueToday: return Theme.accent
        case .overdue: return Theme.danger
        default: return Theme.textSecondary
        }
    }

    private func formattedDueDate(_ bill: Bill) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: bill.dueDate)
    }

    private func formattedNextDue(_ bill: Bill) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: calculateNextDueDate(bill: bill, from: Date()))
    }
}
