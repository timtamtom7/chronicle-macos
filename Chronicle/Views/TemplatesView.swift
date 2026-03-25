import SwiftUI

struct TemplatesView: View {
    @EnvironmentObject var billStore: BillStore
    @Binding var isPresented: Bool

    @State private var showAddTemplate = false
    @State private var editingTemplate: BillTemplate?
    @State private var selectedTemplate: BillTemplate?
    @State private var creatingFromTemplate: BillTemplate?
    @State private var showCreateBillSheet = false
    @State private var templateForCreateBill: BillTemplate?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Bill Templates")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                HStack(spacing: Theme.spacing12) {
                    if !billStore.templates.isEmpty {
                        Button(action: importFromBills) {
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 11))
                                Text("Suggest")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: { showAddTemplate = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11))
                            Text("New")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accent)
                        .cornerRadius(Theme.radiusSmall)
                    }
                    .buttonStyle(.plain)

                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.spacing16)

            Divider()

            if billStore.templates.isEmpty {
                emptyState
            } else {
                templateList
            }
        }
        .frame(width: 480, height: 400)
        .background(Theme.background)
        .sheet(isPresented: $showAddTemplate) {
            TemplateEditorSheet(isPresented: $showAddTemplate)
                .environmentObject(billStore)
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditorSheet(isPresented: .constant(true), editingTemplate: template)
                .environmentObject(billStore)
        }
        .sheet(isPresented: $showCreateBillSheet) {
            if let tmpl = templateForCreateBill {
                CreateBillFromTemplateSheet(isPresented: $showCreateBillSheet, template: tmpl)
                    .environmentObject(billStore)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacing12) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 32))
                .foregroundColor(Theme.textTertiary)

            Text("No templates yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            Text("Templates let you quickly create similar bills")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)

            Button(action: { showAddTemplate = true }) {
                Text("Create Template")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
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

    private var templateList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.spacing8) {
                ForEach(billStore.templates) { template in
                    TemplateCard(template: template)
                        .onTapGesture {
                            templateForCreateBill = template
                            showCreateBillSheet = true
                        }
                        .contextMenu {
                            Button(action: {
                                templateForCreateBill = template
                                showCreateBillSheet = true
                            }) {
                                Label("Use Template", systemImage: "plus.circle")
                            }
                            Button(action: { editingTemplate = template }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(action: { billStore.duplicateTemplate(template) }) {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            Divider()
                            Button(role: .destructive, action: { billStore.deleteTemplate(template.id) }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(Theme.spacing16)
        }
    }

    private func importFromBills() {
        billStore.importTemplatesFromBills()
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: BillTemplate

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .fill(Theme.accent.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: template.category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Theme.spacing8) {
                    Text(template.formattedAmount)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)

                    Text("•")
                        .foregroundColor(Theme.textTertiary)

                    Text(template.recurrence.shortName)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)

                    if template.dueDay > 0 {
                        Text("•")
                            .foregroundColor(Theme.textTertiary)
                        Text("Day \(template.dueDay)")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Template Editor Sheet

struct TemplateEditorSheet: View {
    @EnvironmentObject var billStore: BillStore
    @Binding var isPresented: Bool

    var editingTemplate: BillTemplate?

    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var currency: Currency = .usd
    @State private var dueDay: Int = 1
    @State private var recurrence: Recurrence = .monthly
    @State private var category: Category = .other
    @State private var notes: String = ""
    @State private var reminderThreeDays: Bool = true
    @State private var reminderOneDay: Bool = false
    @State private var reminderDueDate: Bool = false
    @State private var autoMarkPaid: Bool = false

    private var isEditing: Bool { editingTemplate != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        name.count <= 50 &&
        !amountString.isEmpty &&
        (Decimal(string: amountString.replacingOccurrences(of: ",", with: ".")) ?? -1) >= 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Template" : "New Template")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.spacing16)

            Divider()

            ScrollView {
                VStack(spacing: Theme.spacing16) {
                    formField(title: "Template Name", required: true) {
                        TextField("e.g. Monthly Rent", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    formField(title: "Amount", required: true) {
                        HStack(spacing: 8) {
                            Picker("", selection: $currency) {
                                ForEach(Currency.allCases) { curr in
                                    Text(curr.symbol).tag(curr)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 60)

                            TextField("0.00", text: $amountString)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    formField(title: "Due Day of Month") {
                        Stepper(value: $dueDay, in: 1...28) {
                            Text("Day \(dueDay)")
                                .font(.system(size: 13))
                        }
                    }

                    formField(title: "Recurrence") {
                        Picker("", selection: $recurrence) {
                            ForEach(Recurrence.allCases, id: \.self) { rec in
                                Text(rec.rawValue).tag(rec)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    formField(title: "Category") {
                        Picker("", selection: $category) {
                            ForEach(Category.allCases, id: \.self) { cat in
                                HStack {
                                    Image(systemName: cat.icon)
                                    Text(cat.rawValue)
                                }
                                .tag(cat)
                            }
                        }
                        .labelsHidden()
                    }

                    formField(title: "Reminders") {
                        VStack(alignment: .leading, spacing: Theme.spacing8) {
                            reminderToggle(.threeDays, label: "3 days before", isOn: $reminderThreeDays)
                            reminderToggle(.oneDay, label: "1 day before", isOn: $reminderOneDay)
                            reminderToggle(.dueDate, label: "On due date", isOn: $reminderDueDate)
                        }
                    }

                    formField(title: "Auto-mark Paid") {
                        Toggle("Automatically mark as paid on due date", isOn: $autoMarkPaid)
                            .toggleStyle(.switch)
                    }

                    formField(title: "Notes") {
                        TextEditor(text: $notes)
                            .frame(height: 60)
                            .font(.system(size: 13))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                    }
                }
                .padding(Theme.spacing16)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, Theme.spacing12)
                    .padding(.vertical, 8)

                Button(action: save) {
                    Text(isEditing ? "Save" : "Create Template")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.spacing16)
                        .padding(.vertical, 8)
                        .background(isValid ? Theme.accent : Theme.textTertiary)
                        .cornerRadius(Theme.radiusSmall)
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
            }
            .padding(Theme.spacing16)
        }
        .frame(width: 420, height: 560)
        .background(Theme.background)
        .onAppear {
            if let template = editingTemplate {
                name = template.name
                amountString = String(format: "%.2f", NSDecimalNumber(decimal: template.amount).doubleValue)
                currency = template.currency
                dueDay = template.dueDay
                recurrence = template.recurrence
                category = template.category
                notes = template.notes ?? ""
                autoMarkPaid = template.autoMarkPaid
                reminderThreeDays = template.reminderTimings.contains(.threeDays)
                reminderOneDay = template.reminderTimings.contains(.oneDay)
                reminderDueDate = template.reminderTimings.contains(.dueDate)
            } else {
                currency = Currency(rawValue: UserDefaults.standard.string(forKey: "baseCurrency") ?? "USD") ?? .usd
            }
        }
    }

    private func formField<Content: View>(title: String, required: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                if required {
                    Text("*")
                        .foregroundColor(Theme.danger)
                }
            }
            content()
        }
    }

    private func reminderToggle(_ timing: ReminderTiming, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Theme.spacing8) {
            Toggle(label, isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Theme.textPrimary)
        }
    }

    private func save() {
        guard isValid else { return }

        let amountValue = Decimal(string: amountString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let divisor = currency.isZeroDecimal ? Decimal(1) : Decimal(100)
        let amountCents = Int(NSDecimalNumber(decimal: amountValue * divisor).intValue)

        let selectedReminders: [ReminderTiming] = {
            var timings: [ReminderTiming] = []
            if reminderThreeDays { timings.append(.threeDays) }
            if reminderOneDay { timings.append(.oneDay) }
            if reminderDueDate { timings.append(.dueDate) }
            return timings
        }()

        let template = BillTemplate(
            id: editingTemplate?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            amountCents: amountCents,
            currency: currency,
            dueDay: dueDay,
            recurrence: recurrence,
            category: category,
            notes: notes.isEmpty ? nil : notes,
            reminderTimings: selectedReminders,
            autoMarkPaid: autoMarkPaid,
            createdAt: editingTemplate?.createdAt ?? Date()
        )

        billStore.addTemplate(template)
        isPresented = false
    }
}

// MARK: - Create Bill From Template

struct CreateBillFromTemplateSheet: View {
    @EnvironmentObject var billStore: BillStore
    @Binding var isPresented: Bool

    let template: BillTemplate

    @State private var dueDate: Date = Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create Bill from Template")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.spacing16)

            Divider()

            VStack(spacing: Theme.spacing16) {
                HStack {
                    Text("Template:")
                        .foregroundColor(Theme.textSecondary)
                    Text(template.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }

                HStack {
                    Text("Amount:")
                        .foregroundColor(Theme.textSecondary)
                    Text(template.formattedAmount)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: Theme.spacing4) {
                    Text("Due Date")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }

                Text("This will create a new bill with the template's settings. The template itself will not be modified.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

                Button(action: createBill) {
                    Text("Create Bill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.spacing16)
                        .padding(.vertical, 8)
                        .background(Theme.accent)
                        .cornerRadius(Theme.radiusSmall)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.spacing16)
        }
        .frame(width: 380, height: 320)
        .background(Theme.background)
    }

    private func createBill() {
        let bill = billStore.createBillFromTemplate(template, dueDate: dueDate)
        billStore.addBill(bill)
        isPresented = false
    }
}
