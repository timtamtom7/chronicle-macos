import SwiftUI

struct AddBillSheet: View {
    @EnvironmentObject var billStore: BillStore
    @Environment(\.dismiss) private var dismiss

    var editingBill: Bill?
    
    // R16: Upgrade nudge state
    @State private var showUpgradeNudge = false
    @State private var showUpgradeSheet = false
    
    @available(macOS 13.0, *)
    private var subscriptionService: SubscriptionService {
        SubscriptionService.shared
    }
    
    private var isFreeUserAtLimit: Bool {
        guard editingBill == nil else { return false }
        guard let service = Optional(subscriptionService) else { return false }
        return service.status.tier == .free && billStore.bills.count >= 10
    }

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

    // Business fields
    @State private var showBusinessSection: Bool = false
    @State private var isTaxDeductible: Bool = false
    @State private var isReimbursable: Bool = false
    @State private var businessTag: BusinessTag = .other
    @State private var invoiceReference: String = ""
    @State private var attachedInvoiceURL: URL? = nil
    @State private var showInvoicePanel: Bool = false
    @State private var receiptURL: URL? = nil
    @State private var showReceiptPanel: Bool = false

    // Split with household
    @State private var splitWithHousehold: Bool = false
    @State private var shareAmounts: [UUID: String] = [:]  // memberId -> amount string

    @State private var showValidationError = false
    @State private var validationMessage = ""

    @ObservedObject private var householdService = HouseholdService.shared
    @ObservedObject private var splitService = SplitBillService.shared

    private var isEditing: Bool { editingBill != nil }

    private var hasHousehold: Bool {
        householdService.household != nil
    }

    private var currentAmountCents: Int {
        let amountValue = Decimal(string: amountString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let divisor = currency.isZeroDecimal ? Decimal(1) : Decimal(100)
        return Int(NSDecimalNumber(decimal: amountValue * divisor).intValue)
    }

    private var shareTotalCents: Int {
        shareAmounts.values.reduce(0) { total, str in
            let value = Decimal(string: str.replacingOccurrences(of: ",", with: ".")) ?? 0
            return total + Int(NSDecimalNumber(decimal: value * 100).intValue)
        }
    }

    private var sharesValid: Bool {
        if !splitWithHousehold { return true }
        let total = currentAmountCents
        guard total > 0, shareAmounts.count == householdService.household?.members.count else { return false }
        return shareTotalCents == total
    }

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
            // R16: Upgrade nudge banner for free users at limit
            if isFreeUserAtLimit && !showUpgradeNudge {
                upgradeNudgeBanner
            }

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

                    // Split with Household
                    if hasHousehold {
                        splitSection
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

                    // Business Section
                    businessSection
                }
                .padding(Theme.spacing16)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: Theme.sheetMedium.width)
        .background(Theme.background)
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptView(isPresented: $showUpgradeSheet, trigger: .billLimit)
        }
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

                // Load existing split
                if let existingSplit = splitService.getSplit(for: bill.id) {
                    splitWithHousehold = true
                    for share in existingSplit.splits {
                        shareAmounts[share.memberId] = String(format: "%.2f", Double(share.amountCents) / 100.0)
                    }
                }

                // Load business fields
                isTaxDeductible = bill.isTaxDeductible
                isReimbursable = bill.isReimbursable
                businessTag = bill.businessTag ?? .other
                invoiceReference = bill.invoiceReference ?? ""
                attachedInvoiceURL = bill.attachedInvoiceURL
                receiptURL = bill.receiptURL
                showBusinessSection = isTaxDeductible || isReimbursable || bill.businessTag != nil || bill.invoiceReference != nil || bill.attachedInvoiceURL != nil || bill.receiptURL != nil
            } else {
                currency = Currency(rawValue: UserDefaults.standard.string(forKey: "baseCurrency") ?? "USD") ?? .usd
            }
        }
    }

    // MARK: - Split Section

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            HStack {
                Text("Split with Household")
                    .font(.footnote)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Toggle("", isOn: $splitWithHousehold)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("Split with household")
                    .accessibilityHint("Toggle to split this bill with household members")
            }

            if splitWithHousehold {
                if let household = householdService.household {
                    // Split equally button
                    Button("Split Equally") {
                        splitEqually()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .accessibilityLabel("Split equally among members")
                    .accessibilityHint("Divides the bill amount equally among all household members")

                    // Member share rows
                    ForEach(household.members) { member in
                        memberShareRow(member)
                    }

                    // Validation
                    if currentAmountCents > 0 {
                        let diff = abs(shareTotalCents - currentAmountCents)
                        if shareTotalCents < currentAmountCents {
                            Text("Remaining: \(formatCents(currentAmountCents - shareTotalCents))")
                                .font(.caption)
                                .foregroundColor(Theme.warning)
                        } else if shareTotalCents > currentAmountCents {
                            Text("Over by: \(formatCents(shareTotalCents - currentAmountCents))")
                                .font(.caption)
                                .foregroundColor(Theme.danger)
                        } else {
                            Text("Shares add up correctly")
                                .font(.caption)
                                .foregroundColor(Theme.success)
                        }
                    }

                    // Show existing split if editing
                    if isEditing, let existingSplit = splitService.getSplit(for: editingBill!.id) {
                        Text("Current split: \(existingSplit.splits.count) members")
                            .font(.caption)
                            .foregroundColor(Theme.textTertiary)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - R16: Upgrade Nudge
    
    private var upgradeNudgeBanner: some View {
        HStack(spacing: Theme.spacing8) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.body)
                .foregroundColor(Theme.accent)
            
            Text("Upgrade for unlimited bills")
                .font(.callout)
                .foregroundColor(Theme.textPrimary)
            
            Spacer()
            
            Button("Upgrade") {
                showUpgradeSheet = true
            }
            .font(.footnote)
            .foregroundColor(Theme.textOnAccent)
            .padding(.horizontal, Theme.spacing12)
            .padding(.vertical, 5)
            .background(Theme.accent)
            .cornerRadius(Theme.radiusSmall)
            .accessibilityLabel("Upgrade to Pro")
            
            Button(action: { showUpgradeNudge = true }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss upgrade nudge")
        }
        .padding(Theme.spacing12)
        .background(Theme.accent.opacity(0.08))
    }

    private var businessSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            // Section toggle
            HStack {
                Text("Business")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Toggle("", isOn: $showBusinessSection)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("Business section")
                    .accessibilityHint("Toggle to show business-related fields for this bill")
            }

            if showBusinessSection {
                VStack(alignment: .leading, spacing: Theme.spacing12) {
                    // Tax Deductible
                    Toggle("Tax Deductible", isOn: $isTaxDeductible)
                        .toggleStyle(.switch)
                        .accessibilityLabel("Tax deductible")
                        .accessibilityHint("Mark this bill as tax deductible for tax reporting")

                    // Reimbursable
                    Toggle("Reimbursable", isOn: $isReimbursable)
                        .toggleStyle(.switch)
                        .accessibilityLabel("Reimbursable")
                        .accessibilityHint("Mark this bill as reimbursable for expense tracking")

                    // Business Tag
                    VStack(alignment: .leading, spacing: Theme.spacing4) {
                        Text("Business Tag")
                            .font(.footnote)
                            .foregroundColor(Theme.textSecondary)
                        Picker("", selection: $businessTag) {
                            ForEach(BusinessTag.allCases) { tag in
                                HStack {
                                    Image(systemName: tag.icon)
                                    Text(tag.rawValue)
                                }
                                .tag(tag)
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel("Business tag")
                    }

                    // Invoice Reference
                    VStack(alignment: .leading, spacing: Theme.spacing4) {
                        Text("Invoice #")
                            .font(.footnote)
                            .foregroundColor(Theme.textSecondary)
                        TextField("e.g. INV-2024-001", text: $invoiceReference)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Invoice number")
                            .accessibilityHint("Enter the vendor invoice number")
                    }

                    // Attach Invoice
                    HStack {
                        Button(action: { showInvoicePanel = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "paperclip")
                                Text(attachedInvoiceURL != nil ? "Change Invoice" : "Attach Invoice (PDF)")
                            }
                            .font(.footnote)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Attach invoice PDF")
                        .accessibilityHint("Opens a file picker to attach a PDF invoice")

                        if let url = attachedInvoiceURL {
                            Text(url.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Button(action: { attachedInvoiceURL = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(Theme.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove attached invoice")
                        }
                    }
                    .fileImporter(
                        isPresented: $showInvoicePanel,
                        allowedContentTypes: [.pdf],
                        allowsMultipleSelection: false
                    ) { result in
                        if case .success(let urls) = result, let url = urls.first {
                            attachedInvoiceURL = url
                        }
                    }

                    // Attach Receipt
                    HStack {
                        Button(action: { showReceiptPanel = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "photo")
                                Text(receiptURL != nil ? "Change Receipt" : "Attach Receipt (Image)")
                            }
                            .font(.footnote)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Attach receipt image")
                        .accessibilityHint("Opens a file picker to attach a receipt image")

                        if let url = receiptURL {
                            Text(url.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Button(action: { receiptURL = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(Theme.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove attached receipt")
                        }
                    }
                    .fileImporter(
                        isPresented: $showReceiptPanel,
                        allowedContentTypes: [.jpeg, .png, .heic],
                        allowsMultipleSelection: false
                    ) { result in
                        if case .success(let urls) = result, let url = urls.first {
                            receiptURL = url
                        }
                    }
                }
                .padding(.top, Theme.spacing4)
            }
        }
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    private func memberShareRow(_ member: HouseholdMember) -> some View {
        HStack(spacing: Theme.spacing8) {
            Image(systemName: member.avatarName)
                .font(.body)
                .foregroundColor(Color(hex: member.colorHex))
                .accessibilityHidden(true)
                .frame(width: 20)

            Text(member.name)
                .font(.body)
                .foregroundColor(Theme.textPrimary)

            Spacer()

            TextField("0.00", text: Binding(
                get: { shareAmounts[member.id] ?? "" },
                set: { shareAmounts[member.id] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 80)
            .accessibilityLabel("\(member.name) share amount")
        }
        .padding(.vertical, 2)
    }

    private func splitEqually() {
        guard let household = householdService.household else { return }
        let total = currentAmountCents
        let count = household.members.count
        guard count > 0 else { return }
        let baseAmount = total / count
        let remainder = total % count

        for (index, member) in household.members.enumerated() {
            let amount = baseAmount + (index < remainder ? 1 : 0)
            shareAmounts[member.id] = String(format: "%.2f", Double(amount) / 100.0)
        }
    }

    private func formatCents(_ cents: Int) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }

    private func copyInvoiceToDocuments(_ sourceURL: URL?, billId: UUID) -> URL? {
        guard let sourceURL = sourceURL else { return nil }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let invoicesFolder = documentsPath.appendingPathComponent("Chronicle/Invoices", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: invoicesFolder, withIntermediateDirectories: true)
            let destURL = invoicesFolder.appendingPathComponent("\(billId.uuidString)_\(sourceURL.lastPathComponent)")

            // If file already exists at dest, remove it first
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }

            // Start accessing security-scoped resource
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return destURL
        } catch {
            print("Failed to copy invoice: \(error)")
            return nil
        }
    }

    private func copyReceiptToDocuments(_ sourceURL: URL?, billId: UUID) -> URL? {
        guard let sourceURL = sourceURL else { return nil }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let receiptsFolder = documentsPath.appendingPathComponent("Chronicle/Receipts", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: receiptsFolder, withIntermediateDirectories: true)
            let destURL = receiptsFolder.appendingPathComponent("\(billId.uuidString)_\(sourceURL.lastPathComponent)")

            // If file already exists at dest, remove it first
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }

            // Start accessing security-scoped resource
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return destURL
        } catch {
            print("Failed to copy receipt: \(error)")
            return nil
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text(isEditing ? "Edit Bill" : "Add Bill")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Button(action: { dismiss() }) {
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
                dismiss()
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
            createdAt: editingBill?.createdAt ?? Date(),
            isTaxDeductible: showBusinessSection ? isTaxDeductible : false,
            businessTag: showBusinessSection ? businessTag : nil,
            isReimbursable: showBusinessSection ? isReimbursable : false,
            invoiceReference: showBusinessSection && !invoiceReference.isEmpty ? invoiceReference : nil,
            attachedInvoiceURL: showBusinessSection ? copyInvoiceToDocuments(attachedInvoiceURL, billId: editingBill?.id ?? UUID()) : nil,
            receiptURL: copyReceiptToDocuments(receiptURL, billId: editingBill?.id ?? UUID())
        )

        if isEditing {
            billStore.updateBill(bill)
        } else {
            billStore.addBill(bill)
        }

        // Handle split
        if splitWithHousehold, let household = householdService.household {
            let memberAmounts = shareAmounts.compactMap { memberId, amountStr -> (UUID, Int)? in
                guard !amountStr.isEmpty else { return nil }
                let value = Decimal(string: amountStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                let cents = Int(NSDecimalNumber(decimal: value * 100).intValue)
                return (memberId, cents)
            }
            if !memberAmounts.isEmpty {
                splitService.createCustomSplit(
                    billId: bill.id,
                    memberAmounts: memberAmounts.map { (memberId: $0.0, amountCents: $0.1) },
                    totalAmountCents: currentAmountCents
                )
            }
        }

        NotificationCenter.default.post(name: NSNotification.Name("ChronicleDataDidChange"), object: nil)
        dismiss()
    }
}
