import SwiftUI

struct AddBillSheet: View {
    @EnvironmentObject var billStore: BillStore
    @Binding var isPresented: Bool

    var editingBill: Bill?

    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var dueDate: Date = Date()
    @State private var recurrence: Recurrence = .monthly
    @State private var category: Category = .other
    @State private var notes: String = ""
    @State private var reminderTiming: ReminderTiming = .none
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
                            .onChange(of: name) { newValue in
                                if newValue.count > 50 {
                                    name = String(newValue.prefix(50))
                                }
                            }
                        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text("\(name.count)/50")
                                .font(.system(size: 11))
                                .foregroundColor(name.count > 45 ? Theme.warning : Theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    // Amount
                    formField(title: "Amount", required: true) {
                        HStack {
                            Text("$")
                                .foregroundColor(Theme.textSecondary)
                            TextField("0.00", text: $amountString)
                                .textFieldStyle(.roundedBorder)
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
                    }

                    // Recurrence
                    formField(title: "Recurrence") {
                        Picker("", selection: $recurrence) {
                            ForEach(Recurrence.allCases, id: \.self) { rec in
                                Text(rec.rawValue).tag(rec)
                            }
                        }
                        .pickerStyle(.segmented)
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
                    }

                    // Reminder
                    formField(title: "Reminder") {
                        Picker("", selection: $reminderTiming) {
                            ForEach(ReminderTiming.allCases, id: \.self) { timing in
                                Text(timing.rawValue).tag(timing)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Auto-mark paid
                    formField(title: "Auto-mark Paid") {
                        Toggle("Automatically mark as paid on due date", isOn: $autoMarkPaid)
                            .toggleStyle(.switch)
                    }

                    // Notes
                    formField(title: "Notes (optional)") {
                        TextEditor(text: $notes)
                            .frame(height: 60)
                            .font(.system(size: 13))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                            .onChange(of: notes) { newValue in
                                if newValue.count > 200 {
                                    notes = String(newValue.prefix(200))
                                }
                            }
                        if !notes.isEmpty {
                            Text("\(notes.count)/200")
                                .font(.system(size: 11))
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
                dueDate = bill.dueDate
                recurrence = bill.recurrence
                category = bill.category
                notes = bill.notes ?? ""
                reminderTiming = bill.reminderTimings.first ?? .none
                autoMarkPaid = bill.autoMarkPaid
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text(isEditing ? "Edit Bill" : "Add Bill")
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

            Button(action: save) {
                Text(isEditing ? "Save Changes" : "Add Bill")
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

    // MARK: - Actions

    private func save() {
        guard isValid else { return }

        let amountValue = Decimal(string: amountString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let amountCents = Int(NSDecimalNumber(decimal: amountValue * 100).intValue)

        let calendar = Calendar.current
        let dueDay = calendar.component(.day, from: dueDate)

        let reminders: [ReminderTiming] = reminderTiming == .none ? [] : [reminderTiming]

        let bill = Bill(
            id: editingBill?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            amountCents: amountCents,
            dueDay: dueDay,
            dueDate: dueDate,
            recurrence: recurrence,
            category: category,
            notes: notes.isEmpty ? nil : notes,
            reminderTimings: reminders,
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

        isPresented = false
    }
}
