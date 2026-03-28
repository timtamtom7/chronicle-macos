import SwiftUI

struct AddBillSheet: View {
    @EnvironmentObject var billStore: BillStore
    @Binding var isPresented: Bool

    var editingBill: Bill?

    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var currency: Currency = .usd
    @State private var dueDate: Date = Date()
    @State private var recurrence: Recurrence = .monthly
    @State private var category: Category = .other
    @State private var notes: String = ""
    @State private var reminderThreeDays: Bool = true
    @State private var reminderOneDay: Bool = false
    @State private var reminderDueDate: Bool = false
    @State private var autoMarkPaid: Bool = false

    @State private var showValidationError = false
    @State private var validationMessage = ""

    private var isEditing: Bool { editingBill != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        name.count <= 50 &&
        !amountString.isEmpty &&
        (Decimal(string: amountString.replacingOccurrences(of: ",", with: ".")) ?? -1) >= 0
    }

    private var selectedReminders: [ReminderTiming] {
        var timings: [ReminderTiming] = []
        if reminderThreeDays { timings.append(.threeDays) }
        if reminderOneDay { timings.append(.oneDay) }
        if reminderDueDate { timings.append(.dueDate) }
        return timings
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Form
            ScrollView {
                VStack(spacing: Theme.spacing16) {
                    // Name
                    formField(title: "Bill Name", required: true) {
                        TextField("e.g. Rent, Internet, Netflix", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Bill name")
                            .accessibilityHint("Enter the name of the bill, up to 50 characters")
                            .onChange(of: name) { newValue in
                                if newValue.count > 50 {
                                    name = String(newValue.prefix(50))
                                }
                            }
                        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text("\(name.count)/50")
                                .font(.caption)
                                .foregroundColor(name.count > 45 ? Theme.warning : Theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    // Amount + Currency
                    formField(title: "Amount", required: true) {
                        HStack(spacing: 8) {
                            // Currency Picker
                            Picker("", selection: $currency) {
                                ForEach(Currency.allCases) { curr in
                                    Text(curr.symbol).tag(curr)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 60)
                            .accessibilityLabel("Currency")
                            .accessibilityHint("Select the currency for this bill")

                            TextField("0.00", text: $amountString)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Bill amount")
                                .accessibilityHint("Enter the bill amount")
                        }
                    }

                    // Due Date
                    formField(title: "Due Date", required: true) {
                        DatePicker(
                            "",
                            selection: $dueDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .accessibilityLabel("Due date")
                        .accessibilityHint("Select the due date for this bill")
                    }

                    // Recurrence
                    formField(title: "Recurrence") {
                        Picker("", selection: $recurrence) {
                            ForEach(Recurrence.allCases, id: \.self) { rec in
                                Text(rec.rawValue).tag(rec)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Recurrence")
                        .accessibilityHint("Select how often this bill recurs")
                    }

                    // Category
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
                        .accessibilityLabel("Category")
                        .accessibilityHint("Select the category for this bill")
                    }

                    // Reminders
                    formField(title: "Reminders") {
                        VStack(alignment: .leading, spacing: Theme.spacing8) {
                            reminderToggle(timing: .threeDays, label: "3 days before", isOn: $reminderThreeDays)
                            reminderToggle(timing: .oneDay, label: "1 day before", isOn: $reminderOneDay)
                            reminderToggle(timing: .dueDate, label: "On due date", isOn: $reminderDueDate)
                            Text("Reminders are sent at 9:00 AM")
                                .font(.caption)
                                .foregroundColor(Theme.textTertiary)
                                .padding(.top, 2)
                        }
                    }

                    // Auto-mark paid
                    formField(title: "Auto-mark Paid") {
                        Toggle("Automatically mark as paid on due date", isOn: $autoMarkPaid)
                            .toggleStyle(.switch)
                            .accessibilityLabel("Auto-mark paid")
                            .accessibilityHint("When enabled, this bill will be automatically marked as paid on its due date")
                    }

                    // Notes
                    formField(title: "Notes (optional)") {
                        TextEditor(text: $notes)
                            .frame(height: 60)
                            .font(.body)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                            .accessibilityLabel("Notes")
                            .accessibilityHint("Enter optional notes for this bill, up to 200 characters")
                            .onChange(of: notes) { newValue in
                                if newValue.count > 200 {
                                    notes = String(newValue.prefix(200))
                                }
                            }
                        if !notes.isEmpty {
                            Text("\(notes.count)/200")
                                .font(.caption)
                                .foregroundColor(notes.count > 180 ? Theme.warning : Theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
                .padding(Theme.spacing16)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 500)
        .background(Theme.background)
        .onAppear {
            if let bill = editingBill {
                name = bill.name
                amountString = String(format: "%.2f", NSDecimalNumber(decimal: bill.amount).doubleValue)
                currency = bill.currency
                dueDate = bill.dueDate
                recurrence = bill.recurrence
                category = bill.category
                notes = bill.notes ?? ""
                autoMarkPaid = bill.autoMarkPaid
                reminderThreeDays = bill.reminderTimings.contains(.threeDays)
                reminderOneDay = bill.reminderTimings.contains(.oneDay)
                reminderDueDate = bill.reminderTimings.contains(.dueDate)
            } else {
                currency = Currency(rawValue: UserDefaults.standard.string(forKey: "baseCurrency") ?? "USD") ?? .usd
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text(isEditing ? "Edit Bill" : "Add Bill")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.footnote)
                    .foregroundColor(Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .accessibilityHint("Closes the add bill sheet without saving")
        }
        .padding(Theme.spacing16)
    }

    private func formField<Content: View>(title: String, required: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.footnote)
                    .foregroundColor(Theme.textSecondary)
                if required {
                    Text("*")
                        .foregroundColor(Theme.textTertiary)
                }
            }
            content()
        }
    }

    private func reminderToggle(timing: ReminderTiming, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Theme.spacing8) {
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .accessibilityLabel("Remind me \(label)")
            Text(label)
                .font(.body)
                .foregroundColor(Theme.textPrimary)
        }
    }

    private var footer: some View {
        HStack {
            if isEditing {
                Spacer()
            }

            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.plain)
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal, Theme.spacing12)
            .padding(.vertical, 8)
            .accessibilityLabel("Cancel")
            .accessibilityHint("Closes this sheet without saving")

            Button(action: save) {
                Text(isEditing ? "Save Changes" : "Add Bill")
                    .font(.footnote)
                    .foregroundColor(Theme.textOnAccent)
                    .padding(.horizontal, Theme.spacing16)
                    .padding(.vertical, 8)
                    .background(isValid ? Theme.accent : Theme.textTertiary)
                    .cornerRadius(Theme.radiusSmall)
            }
            .buttonStyle(.plain)
            .disabled(!isValid)
            .accessibilityLabel(isEditing ? "Save changes" : "Add bill")
            .accessibilityHint(isEditing ? "Saves the edited bill" : "Creates a new bill with the entered details")
        }
        .padding(Theme.spacing16)
    }

    // MARK: - Actions

    private func save() {
        guard isValid else { return }

        let amountValue = Decimal(string: amountString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let divisor = currency.isZeroDecimal ? Decimal(1) : Decimal(100)
        let amountCents = Int(NSDecimalNumber(decimal: amountValue * divisor).intValue)

        let calendar = Calendar.current
        let dueDay = calendar.component(.day, from: dueDate)

        let bill = Bill(
            id: editingBill?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            amountCents: amountCents,
            currency: currency,
            dueDay: dueDay,
            dueDate: dueDate,
            recurrence: recurrence,
            category: category,
            notes: notes.isEmpty ? nil : notes,
            reminderTimings: selectedReminders,
            autoMarkPaid: autoMarkPaid,
            isActive: true,
            isPaid: editingBill?.isPaid ?? false,
            createdAt: editingBill?.createdAt ?? Date()
        )

        if isEditing {
            billStore.updateBill(bill)
        } else {
            billStore.addBill(bill)
        }

        NotificationCenter.default.post(name: NSNotification.Name("ChronicleDataDidChange"), object: nil)
        isPresented = false
    }
}
