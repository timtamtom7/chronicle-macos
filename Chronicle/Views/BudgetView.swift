import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var billStore: BillStore
    @Binding var isPresented: Bool

    @State private var showAddBudget = false
    @State private var editingBudget: CategoryBudget?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Budgets")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Button(action: { showAddBudget = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(Theme.fontCaption)
                        Text("Add")
                        .font(.system(size: 12))
                    }
                    .foregroundColor(Theme.textOnAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accent)
                    .cornerRadius(Theme.radiusSmall)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add budget")
                .accessibilityHint("Create a new budget for a category")

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(Theme.fontLabel)
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .accessibilityHint("Closes the budgets view")
            }
            .padding(Theme.spacing16)

            Divider()

            if billStore.categoryBudgets.isEmpty {
                emptyState
            } else {
                budgetList
            }
        }
        .frame(width: 480, height: 420)
        .background(Theme.background)
        .sheet(isPresented: $showAddBudget) {
            BudgetEditorSheet(isPresented: $showAddBudget)
                .environmentObject(billStore)
        }
        .sheet(item: $editingBudget) { budget in
            BudgetEditorSheet(isPresented: .constant(true), editingBudget: budget)
                .environmentObject(billStore)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacing12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 32))
                .foregroundColor(Theme.textTertiary)

            Text("No budgets set")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            Text("Set spending limits for categories to track your bills")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            Button(action: { showAddBudget = true }) {
                Text("Add Budget")
                    .font(Theme.fontLabel)
                    .foregroundColor(Theme.textOnAccent)
                    .padding(.horizontal, Theme.spacing16)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .cornerRadius(Theme.radiusSmall)
            }
            .buttonStyle(.plain)
            .padding(.top, Theme.spacing8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var budgetList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.spacing8) {
                ForEach(billStore.categoryBudgets) { budget in
                    BudgetCard(budget: budget)
                        .onTapGesture {
                            editingBudget = budget
                        }
                        .contextMenu {
                            Button(action: { editingBudget = budget }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            Divider()
                            Button(role: .destructive, action: { billStore.deleteBudget(budget.id) }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(Theme.spacing16)
        }
    }
}

// MARK: - Budget Card

struct BudgetCard: View {
    @EnvironmentObject var billStore: BillStore
    let budget: CategoryBudget

    private var spent: Decimal {
        billStore.spendingForCategory(budget.category)
    }

    private var progress: Double {
        guard budget.monthlyLimit > 0 else { return 0 }
        let p = NSDecimalNumber(decimal: spent / budget.monthlyLimit).doubleValue
        return min(p, 1.5)
    }

    private var status: BudgetStatus {
        let (_, _, s) = billStore.budgetStatus(for: budget.category)
        return s
    }

    private var statusColor: Color {
        switch status {
        case .underBudget: return Theme.success
        case .approachingBudget: return Theme.warning
        case .atBudget: return Theme.accent
        case .overBudget: return Theme.danger
        }
    }

    var body: some View {
        VStack(spacing: Theme.spacing8) {
            HStack {
                Image(systemName: budget.category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.accent)
                    .frame(width: 24)

                Text(budget.category.rawValue)
                    .font(Theme.fontLabel)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Text("\(formattedCurrency(spent)) / \(budget.formattedLimit)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.surfaceSecondary)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Int(progress * 100))% used")
                    .font(Theme.fontCaption)
                    .foregroundColor(progress >= 1.0 ? Theme.danger : Theme.textTertiary)

                Spacer()

                if progress >= 1.0 {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Over budget")
                            .font(Theme.fontCaption)
                    }
                    .foregroundColor(Theme.danger)
                } else if progress >= 0.9 {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                        Text("Near limit")
                            .font(Theme.fontCaption)
                    }
                    .foregroundColor(Theme.warning)
                }
            }
        }
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func formattedCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

// MARK: - Budget Editor Sheet

struct BudgetEditorSheet: View {
    @EnvironmentObject var billStore: BillStore
    @Binding var isPresented: Bool

    var editingBudget: CategoryBudget?

    @State private var selectedCategory: Category = .other
    @State private var limitString: String = ""
    @State private var isEnabled: Bool = true

    private var isEditing: Bool { editingBudget != nil }

    private var isValid: Bool {
        !limitString.isEmpty &&
        (Decimal(string: limitString.replacingOccurrences(of: ",", with: ".")) ?? -1) > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit Budget" : "Add Budget")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(Theme.fontLabel)
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .accessibilityHint("Closes this sheet without saving")
            }
            .padding(Theme.spacing16)

            Divider()

            VStack(spacing: Theme.spacing16) {
                if !isEditing {
                    VStack(alignment: .leading, spacing: Theme.spacing4) {
                        Text("Category")
                            .font(Theme.fontLabel)
                            .foregroundColor(Theme.textSecondary)
                        Picker("", selection: $selectedCategory) {
                            ForEach(Category.allCases, id: \.self) { cat in
                                HStack {
                                    Image(systemName: cat.icon)
                                    Text(cat.rawValue)
                                }
                                .tag(cat)
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel("Category")
                        .accessibilityHint("Select the category for this budget")
                    }
                }

                VStack(alignment: .leading, spacing: Theme.spacing4) {
                    Text("Monthly Limit")
                        .font(Theme.fontLabel)
                        .foregroundColor(Theme.textSecondary)
                    HStack(spacing: 8) {
                        Text("$")
                            .foregroundColor(Theme.textSecondary)
                        TextField("0.00", text: $limitString)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Monthly limit amount")
                            .accessibilityHint("Enter the monthly spending limit for this category")
                    }
                }

                Toggle("Budget Enabled", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Budget enabled")
                    .accessibilityHint("Toggle to enable or disable this budget")

                Text("You'll see spending alerts when you approach or exceed this limit.")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(Theme.spacing16)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, Theme.spacing12)
                    .padding(.vertical, 8)
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Closes this sheet without saving")

                Button(action: save) {
                    Text(isEditing ? "Save" : "Add Budget")
                        .font(Theme.fontLabel)
                        .foregroundColor(Theme.textOnAccent)
                        .padding(.horizontal, Theme.spacing16)
                        .padding(.vertical, 8)
                        .background(isValid ? Theme.accent : Theme.textTertiary)
                        .cornerRadius(Theme.radiusSmall)
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
                .accessibilityLabel(isEditing ? "Save budget" : "Add budget")
                .accessibilityHint(isEditing ? "Saves the edited budget" : "Creates a new budget")
            }
            .padding(Theme.spacing16)
        }
        .frame(width: 380, height: 300)
        .background(Theme.background)
        .onAppear {
            if let budget = editingBudget {
                selectedCategory = budget.category
                limitString = String(format: "%.2f", NSDecimalNumber(decimal: budget.monthlyLimit).doubleValue)
                isEnabled = budget.isEnabled
            }
        }
    }

    private func save() {
        guard isValid else { return }

        let amount = Decimal(string: limitString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let limitCents = Int(NSDecimalNumber(decimal: amount * 100).intValue)

        let budget = CategoryBudget(
            id: editingBudget?.id ?? UUID(),
            category: selectedCategory,
            monthlyLimitCents: limitCents,
            isEnabled: isEnabled,
            createdAt: editingBudget?.createdAt ?? Date()
        )

        billStore.saveBudget(budget)
        isPresented = false
    }
}
