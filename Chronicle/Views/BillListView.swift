import SwiftUI

struct BillListView: View {
    @EnvironmentObject var billStore: BillStore
    @State private var showingAddSheet = false
    @State private var selectedBill: Bill?
    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var showDeleteAlert = false
    @State private var billToDelete: Bill?

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar
            sidebar

            Divider()

            // Main content
            VStack(spacing: 0) {
                // Toolbar
                toolbar

                Divider()

                // Bill list
                billList
            }
        }
        .frame(minWidth: 560, minHeight: 400)
        .background(Theme.background)
        .sheet(isPresented: $showingAddSheet) {
            AddBillSheet(isPresented: $showingAddSheet)
        }
        .sheet(item: $selectedBill) { bill in
            AddBillSheet(isPresented: Binding(
                get: { selectedBill != nil },
                set: { if !$0 { selectedBill = nil } }
            ), editingBill: bill)
        }
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

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BILLS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, Theme.spacing16)
                .padding(.top, Theme.spacing16)
                .padding(.bottom, Theme.spacing8)

            // All bills
            sidebarItem(title: "All Bills", count: billStore.bills.count, selected: selectedCategory == nil) {
                selectedCategory = nil
            }

            Text("CATEGORIES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, Theme.spacing16)
                .padding(.top, Theme.spacing24)
                .padding(.bottom, Theme.spacing8)

            ForEach(Category.allCases, id: \.self) { cat in
                let count = billStore.bills.filter { $0.category == cat }.count
                if count > 0 {
                    sidebarItem(title: cat.rawValue, icon: cat.icon, count: count, selected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }

            Spacer()

            // Stats at bottom of sidebar
            VStack(spacing: Theme.spacing8) {
                Divider()
                statsView
            }
            .padding(Theme.spacing16)
        }
        .frame(width: 200)
        .background(Theme.surfaceSecondary)
    }

    private func sidebarItem(title: String, icon: String? = nil, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(selected ? Theme.accent : Theme.textSecondary)
                        .frame(width: 16)
                }
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(.horizontal, Theme.spacing16)
            .padding(.vertical, Theme.spacing8)
            .background(selected ? Theme.accent.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var statsView: some View {
        VStack(spacing: Theme.spacing4) {
            HStack {
                Text("Due this month")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                Text(formatCurrency(billStore.totalDueThisMonth))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.accent)
            }
            HStack {
                Text("Paid this month")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                Text(formatCurrency(billStore.totalPaidThisMonth))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.success)
            }
            HStack {
                Text("Remaining")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                Text(formatCurrency(billStore.totalRemainingThisMonth))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.warning)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: Theme.spacing12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textTertiary)
                TextField("Search bills...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .frame(width: 200)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.spacing8)
            .padding(.vertical, 6)
            .background(Theme.surfaceSecondary)
            .cornerRadius(Theme.radiusSmall)

            Spacer()

            // Add button
            Button(action: { showingAddSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Add Bill")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, Theme.spacing12)
                .padding(.vertical, 6)
                .background(Theme.accent)
                .cornerRadius(Theme.radiusSmall)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing12)
    }

    // MARK: - Bill List

    private var billList: some View {
        ScrollView {
            VStack(spacing: Theme.spacing24) {
                // Due this week
                if !dueThisWeekBills.isEmpty {
                    billSection(title: "Due This Week", bills: dueThisWeekBills, accentColor: Theme.accent)
                }

                // Upcoming
                if !upcomingBills.isEmpty {
                    billSection(title: "Upcoming", bills: upcomingBills, accentColor: Theme.textTertiary)
                }

                // Past due
                if !pastDueBills.isEmpty {
                    billSection(title: "Past Due", bills: pastDueBills, accentColor: Theme.danger)
                }

                // Paid
                if !paidBills.isEmpty {
                    billSection(title: "Paid", bills: paidBills, accentColor: Theme.success)
                }

                if filteredBills.isEmpty {
                    emptyState
                }
            }
            .padding(Theme.spacing16)
        }
    }

    private var filteredBills: [Bill] {
        var bills = billStore.bills

        if !searchText.isEmpty {
            bills = bills.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        if let cat = selectedCategory {
            bills = bills.filter { $0.category == cat }
        }

        return bills
    }

    private var dueThisWeekBills: [Bill] {
        filteredBills.filter { $0.status() == .dueToday || $0.status() == .dueSoon }
    }

    private var upcomingBills: [Bill] {
        filteredBills.filter { $0.status() == .upcoming }
    }

    private var pastDueBills: [Bill] {
        filteredBills.filter { $0.status() == .overdue }
    }

    private var paidBills: [Bill] {
        filteredBills.filter { $0.status() == .paid }
    }

    private func billSection(title: String, bills: [Bill], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .tracking(0.05)

            VStack(spacing: Theme.spacing8) {
                ForEach(bills) { bill in
                    BillRowView(
                        bill: bill,
                        onTogglePaid: { billStore.markPaid(bill, paid: !bill.isPaid) },
                        onEdit: { selectedBill = bill },
                        onDelete: {
                            billToDelete = bill
                            showDeleteAlert = true
                        }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacing12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(Theme.textTertiary)

            Text("No bills yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            Text("Click + to add your first bill and never miss a payment.")
                .font(.system(size: 13))
                .foregroundColor(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacing32)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}

// MARK: - Bill Row View

struct BillRowView: View {
    let bill: Bill
    let onTogglePaid: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            // Checkbox
            Button(action: onTogglePaid) {
                Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(checkboxColor)
            }
            .buttonStyle(.plain)

            // Left border accent
            RoundedRectangle(cornerRadius: 2)
                .fill(leftBorderColor)
                .frame(width: 3)

            // Bill info
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(bill.isPaid ? Theme.textTertiary : Theme.textPrimary)
                    .strikethrough(bill.isPaid)

                HStack(spacing: Theme.spacing4) {
                    Text(bill.formattedAmount)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.textSecondary)

                    Text("·")
                        .foregroundColor(Theme.textTertiary)

                    Text(bill.recurrence.shortName)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)

                    Text("·")
                        .foregroundColor(Theme.textTertiary)

                    Image(systemName: bill.category.icon)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)

                    Text(bill.category.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
            }

            Spacer()

            // Due date
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedDueDate)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(dueDateColor)

                if bill.recurrence != .none {
                    Text("Next: \(formattedNextDue)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
            }

            // Actions (visible on hover)
            if isHovering {
                HStack(spacing: Theme.spacing4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.danger)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Theme.spacing12)
        .background(isHovering ? Theme.surfaceSecondary : Theme.surface)
        .cornerRadius(Theme.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(leftBorderColor.opacity(0.3), lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var checkboxColor: Color {
        bill.isPaid ? Theme.success : Theme.textTertiary
    }

    private var leftBorderColor: Color {
        switch bill.status() {
        case .dueToday, .dueSoon: return Theme.accent
        case .upcoming: return Theme.border
        case .overdue: return Theme.danger
        case .paid: return Theme.success
        }
    }

    private var dueDateColor: Color {
        switch bill.status() {
        case .dueToday: return Theme.accent
        case .overdue: return Theme.danger
        default: return Theme.textSecondary
        }
    }

    private var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: bill.dueDate)
    }

    private var formattedNextDue: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: calculateNextDueDate(bill: bill, from: Date()))
    }
}
