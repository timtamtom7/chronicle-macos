import SwiftUI

// MARK: - Sort Order

enum BillSortOrder: String, CaseIterable {
    case dueDate = "Due Date"
    case amountHighToLow = "Amount (High to Low)"
    case alphabetical = "Alphabetical"

    var keyboardShortcut: String {
        switch self {
        case .dueDate: return "d"
        case .amountHighToLow: return "a"
        case .alphabetical: return "l"
        }
    }
}

struct BillListView: View {
    @EnvironmentObject var billStore: BillStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingAddSheet = false
    @State private var selectedBill: Bill?
    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var showDeleteAlert = false
    @State private var billToDelete: Bill?
    @State private var sortOrder: BillSortOrder = .dueDate
    @State private var showPastBills = false
    @State private var cachedFilteredBills: [Bill] = []
    @State private var cachedSearchText: String = ""
    @State private var cachedCategory: Category?
    @State private var cachedSortOrder: BillSortOrder = .dueDate

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
                    sidebarItem(
                        title: cat.rawValue,
                        icon: cat.icon,
                        count: count,
                        selected: selectedCategory == cat,
                        color: CategoryColor.map[cat]
                    ) {
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

    private func sidebarItem(title: String, icon: String? = nil, count: Int, selected: Bool, color: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(selected ? (color ?? Theme.accent) : Theme.textSecondary)
                        .frame(width: 16)
                } else {
                    Circle()
                        .fill(color ?? Theme.textTertiary)
                        .frame(width: 8, height: 8)
                        .opacity(selected ? 1 : 0.5)
                }
                Text(title)
                    .font(Theme.fontBody)
                    .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(.horizontal, Theme.spacing16)
            .padding(.vertical, Theme.spacing8)
            .background(selected ? Theme.accent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) bills\(selected ? ", selected" : "")")
    }

    private var statsView: some View {
        VStack(spacing: Theme.spacing4) {
            HStack {
                Text("Due this month")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                Text(formatCurrency(billStore.totalDueThisMonth))
                    .font(Theme.fontLabel)
                    .foregroundColor(Theme.accent)
                    .accessibilityLabel("Due this month: \(formatCurrency(billStore.totalDueThisMonth))")
            }
            HStack {
                Text("Paid this month")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                Text(formatCurrency(billStore.totalPaidThisMonth))
                    .font(Theme.fontLabel)
                    .foregroundColor(Theme.success)
                    .accessibilityLabel("Paid this month: \(formatCurrency(billStore.totalPaidThisMonth))")
            }
            HStack {
                Text("Remaining")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                Text(formatCurrency(billStore.totalRemainingThisMonth))
                    .font(Theme.fontLabel)
                    .foregroundColor(Theme.warning)
                    .accessibilityLabel("Remaining: \(formatCurrency(billStore.totalRemainingThisMonth))")
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
                    .font(Theme.fontBody)
                    .frame(width: 200)
                    .accessibilityLabel("Search bills")
                    .accessibilityHint("Type to filter bills by name")
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, Theme.spacing8)
            .padding(.vertical, 6)
            .background(Theme.surfaceSecondary)
            .cornerRadius(Theme.radiusSmall)

            Spacer()

            // Sort picker
            Menu {
                ForEach(BillSortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        HStack {
                            Text(order.rawValue)
                            if sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(Theme.fontCaption)
                    Text(sortOrder.rawValue)
                        .font(.system(size: 12))
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, Theme.spacing8)
                .padding(.vertical, 5)
                .background(Theme.surfaceSecondary)
                .cornerRadius(Theme.radiusSmall)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Sort bills by \(sortOrder.rawValue)")
            .accessibilityHint("Opens menu to change sort order")

            // Add button
            Button(action: { showingAddSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Add Bill")
                }
                .font(Theme.fontLabel)
                .foregroundColor(Theme.textOnAccent)
                .padding(.horizontal, Theme.spacing12)
                .padding(.vertical, 6)
                .background(Theme.accent)
                .cornerRadius(Theme.radiusSmall)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add new bill")
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

                // Past Bills (recurring paid - collapsible)
                if !paidBills.isEmpty {
                    pastBillsSection
                }

                if cachedFilteredBills.isEmpty {
                    emptyState
                }
            }
            .padding(Theme.spacing16)
            .onAppear {
                updateFilteredBills()
            }
            .onChange(of: searchText) { _ in updateFilteredBills() }
            .onChange(of: selectedCategory) { _ in updateFilteredBills() }
            .onChange(of: sortOrder) { _ in updateFilteredBills() }
            .onChange(of: billStore.bills) { _ in updateFilteredBills() }
        }
    }

    private func updateFilteredBills() {
        var bills = billStore.bills

        if !searchText.isEmpty {
            bills = bills.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        if let cat = selectedCategory {
            bills = bills.filter { $0.category == cat }
        }

        switch sortOrder {
        case .dueDate:
            bills.sort { $0.dueDate < $1.dueDate }
        case .amountHighToLow:
            bills.sort { $0.amountCents > $1.amountCents }
        case .alphabetical:
            bills.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        cachedFilteredBills = bills
    }

    private var pastBillsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Button {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                    showPastBills.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: showPastBills ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                    Text("PAID")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                    Text("(\(paidBills.count))")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textTertiary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Paid bills section, \(paidBills.count) paid bills")
            .accessibilityHint(showPastBills ? "Collapses paid bills list" : "Expands paid bills list")

            if showPastBills {
                VStack(spacing: Theme.spacing8) {
                    ForEach(paidBills) { bill in
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
    }

    private var dueThisWeekBills: [Bill] {
        cachedFilteredBills.filter { $0.status() == .dueToday || $0.status() == .dueSoon }
    }

    private var upcomingBills: [Bill] {
        cachedFilteredBills.filter { $0.status() == .upcoming }
    }

    private var pastDueBills: [Bill] {
        cachedFilteredBills.filter { $0.status() == .overdue }
    }

    private var paidBills: [Bill] {
        cachedFilteredBills.filter { $0.status() == .paid }
    }

    private func billSection(title: String, bills: [Bill], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .tracking(Theme.trackingWide)

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
                .font(Theme.fontBody)
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

    private static let dueDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static let nextDueFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            // Checkbox
            Button(action: onTogglePaid) {
                Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(checkboxColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(bill.isPaid ? "Mark \(bill.name) as unpaid" : "Mark \(bill.name) as paid")
            .accessibilityHint("Toggles the paid status of this bill")

            // Left border accent
            RoundedRectangle(cornerRadius: 2)
                .fill(leftBorderColor)
                .frame(width: 3)
                .accessibilityHidden(true)

            // Bill info
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(bill.isPaid ? Theme.textTertiary : Theme.textPrimary)
                    .strikethrough(bill.isPaid)
                    .accessibilityLabel("\(bill.name), \(bill.formattedAmount)")

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
                        .font(Theme.fontCaption)
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
                    .font(Theme.fontLabel)
                    .foregroundColor(dueDateColor)

                if bill.recurrence != .none {
                    Text("Next: \(formattedNextDue)")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textTertiary)
                }
            }

            // Actions (visible on hover, but keyboard-accessible always)
            HStack(spacing: Theme.spacing4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(bill.name)")
                .accessibilityHint("Opens the edit sheet for this bill")
                .opacity(isHovering ? 1 : 0.3)  // Always visible at 30% for keyboard/VoiceOver users
                .focusable()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.danger)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(bill.name)")
                .accessibilityHint("Permanently deletes this bill")
                .opacity(isHovering ? 1 : 0.3)  // Always visible at 30% for keyboard/VoiceOver users
                .focusable()
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
        if bill.isPaid {
            return Theme.success
        }
        switch bill.status() {
        case .dueToday, .dueSoon: return Theme.accent
        case .upcoming: return CategoryColor.map[bill.category] ?? Theme.border
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
        Self.dueDateFormatter.string(from: bill.dueDate)
    }

    private var formattedNextDue: String {
        Self.nextDueFormatter.string(from: calculateNextDueDate(bill: bill, from: Date()))
    }
}
