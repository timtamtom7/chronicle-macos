import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject var billStore: BillStore
    var showMainWindow: () -> Void

    @State private var showingAddSheet = false
    @State private var selectedBill: Bill?
    @State private var showPermissionBanner = false
    @State private var showSettingsSheet = false
    @State private var showTemplatesSheet = false
    @State private var showBudgetSheet = false
    @State private var showImportExportSheet = false
    @State private var showShareSheet = false
    @State private var showAnalyticsSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Permission banner
            if showPermissionBanner {
                permissionBanner
                Divider()
            }

            // Header
            headerView

            Divider()
                .padding(0)

            // Bill list
            ScrollView {
                VStack(spacing: Theme.spacing8) {
                    if billStore.upcomingBills.isEmpty {
                        emptyState
                    } else {
                        ForEach(billStore.upcomingBills.prefix(5)) { bill in
                            BillCardView(bill: bill, onTogglePaid: togglePaid)
                                .onTapGesture {
                                    selectedBill = bill
                                }
                                .contextMenu {
                                    Button(action: { billStore.createTemplateFromBill(bill) }) {
                                        Label("Save as Template", systemImage: "doc.on.doc")
                                    }
                                    Button(action: { selectedBill = bill }) {
                                        Label("Edit Bill", systemImage: "pencil")
                                    }
                                }
                        }

                        if billStore.upcomingBills.count > 5 {
                            Button(action: showMainWindow) {
                                HStack {
                                    Text("View All Bills")
                                        .font(.footnote)
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                        .accessibilityHidden(true)
                                }
                                .foregroundColor(Theme.accent)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, Theme.spacing8)
                        }
                    }
                }
                .padding(Theme.spacing16)
            }

            Divider()
                .padding(0)

            // Monthly overview footer
            monthlyOverview
        }
        .frame(width: Theme.sheetMedium.width, height: Theme.sheetMedium.height)
        .background(Theme.background)
        .sheet(isPresented: $showingAddSheet) {
            AddBillSheet()
                .environmentObject(billStore)
        }
        .sheet(item: $selectedBill) { bill in
            AddBillSheet(editingBill: bill)
                .environmentObject(billStore)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheet(isPresented: $showSettingsSheet)
        }
        .sheet(isPresented: $showTemplatesSheet) {
            TemplatesView(isPresented: $showTemplatesSheet)
                .environmentObject(billStore)
        }
        .sheet(isPresented: $showBudgetSheet) {
            BudgetView(isPresented: $showBudgetSheet)
                .environmentObject(billStore)
        }
        .sheet(isPresented: $showImportExportSheet) {
            ImportExportView(isPresented: $showImportExportSheet)
                .environmentObject(billStore)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareView(isPresented: $showShareSheet)
                .environmentObject(billStore)
        }
        .sheet(isPresented: $showAnalyticsSheet) {
            AnalyticsView(isPresented: $showAnalyticsSheet)
                .environmentObject(billStore)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAddBillSheet)) { _ in
            showingAddSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationPermissionDenied)) { _ in
            showPermissionBanner = true
        }
        .onAppear {
            checkNotificationPermission()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("Chronicle")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            Spacer()

            // Quick actions
            HStack(spacing: Theme.spacing12) {
                // Pay all due today button
                if !billStore.upcomingBills.filter({ $0.status() == .dueToday }).isEmpty {
                    Button(action: payAllDueToday) {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text("Pay All Due")
                                .font(.caption)
                        }
                        .foregroundColor(Theme.success)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pay all due today")
                    .accessibilityHint("Marks all bills due today as paid")
                }

                Button(action: { showSettingsSheet = true }) {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .accessibilityHint("Opens the settings sheet")

                Button(action: { showTemplatesSheet = true }) {
                    Image(systemName: "doc.on.doc")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Templates")
                .accessibilityHint("Opens the bill templates sheet")

                Button(action: { showBudgetSheet = true }) {
                    Image(systemName: "chart.pie")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Budgets")
                .accessibilityHint("Opens the budgets sheet")

                Button(action: { showImportExportSheet = true }) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Import/Export")
                .accessibilityHint("Opens the import export sheet")

                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share")
                .accessibilityHint("Opens the share sheet")

                Button(action: { showAnalyticsSheet = true }) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Analytics")
                .accessibilityHint("Opens the analytics sheet")

                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.body)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.accent)
                .accessibilityLabel("Add bill")
                .accessibilityHint("Opens the add bill sheet")
            }
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing12)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacing12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(Theme.textTertiary)
                .accessibilityHidden(true)

            Text("No upcoming bills")
                .font(.callout)
                .foregroundColor(Theme.textSecondary)

            Text("Click + to add your first bill")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacing32)
    }

    private var permissionBanner: some View {
        HStack(spacing: Theme.spacing8) {
            Image(systemName: "bell.slash.fill")
                .font(.body)
                .foregroundColor(Theme.warning)

            Text("Notifications are off. Enable in System Settings to get reminders.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Button(action: openSystemSettings) {
                Text("Open Settings")
                    .font(.caption)
                    .foregroundColor(Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Settings")
            .accessibilityHint("Opens system notification settings")

            Button(action: { showPermissionBanner = false }) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .accessibilityHint("Dismisses the notification permission warning")
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing8)
        .background(Theme.warning.opacity(0.1))
    }

    private var monthlyOverview: some View {
        VStack(spacing: Theme.spacing8) {
            HStack {
                Text("Monthly Overview")
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: showMainWindow) {
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: Theme.spacing16) {
                overviewItem(title: "Due", value: formatCurrency(billStore.totalDueThisMonth), color: Theme.accent)
                overviewItem(title: "Paid", value: formatCurrency(billStore.totalPaidThisMonth), color: Theme.success)
                overviewItem(title: "Remaining", value: formatCurrency(billStore.totalRemainingThisMonth), color: Theme.warning)
            }
        }
        .padding(Theme.spacing16)
        .background(Theme.surfaceSecondary)
    }

    private func overviewItem(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.callout)
                .foregroundColor(color)
        }
    }

    // MARK: - Helpers

    private func togglePaid(_ bill: Bill) {
        billStore.markPaid(bill, paid: !bill.isPaid)
    }

    private func payAllDueToday() {
        let dueTodayBills = billStore.upcomingBills.filter { $0.status() == .dueToday }
        for bill in dueTodayBills {
            billStore.markPaid(bill, paid: true)
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                showPermissionBanner = settings.authorizationStatus == .denied
            }
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Bill Card View (compact for popover)

struct BillCardView: View {
    let bill: Bill
    let onTogglePaid: (Bill) -> Void

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            // Mark paid button
            Button(action: { onTogglePaid(bill) }) {
                Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(bill.isPaid ? Theme.success : Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(bill.isPaid ? "Mark \(bill.name) as unpaid" : "Mark \(bill.name) as paid")
            .accessibilityHint("Toggles the paid status of this bill")

            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Category icon
            Image(systemName: bill.category.icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 20)

            // Name
            Text(bill.name)
                .font(.callout)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .strikethrough(bill.isPaid)

            Spacer()

            // Amount
            Text(bill.formattedAmount)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(bill.isPaid ? Theme.textTertiary : Theme.textPrimary)

            // Due date
            Text(formattedDueDate)
                .font(.system(size: 12))
                .foregroundColor(dueDateColor)
        }
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var statusColor: Color {
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
        formatter.dateFormat = "MMM d"
        return "Due \(formatter.string(from: bill.dueDate))"
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Binding var isPresented: Bool
    @State private var notificationSoundEnabled = true
    @State private var showingTestNotification = false
    @State private var notificationHour: Int = 9

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
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
                .accessibilityHint("Closes the settings sheet")
            }
            .padding(Theme.spacing16)

            Divider()

            ScrollView {
                VStack(spacing: Theme.spacing16) {
                    // Notifications Section
                    settingsSection(title: "NOTIFICATIONS") {
                        VStack(alignment: .leading, spacing: Theme.spacing12) {
                            Toggle("Notification Sound", isOn: $notificationSoundEnabled)
                                .toggleStyle(.switch)
                                .accessibilityLabel("Notification sound")
                                .accessibilityHint("Toggle to enable or disable notification sound")
                                .onChange(of: notificationSoundEnabled) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: "notificationSoundEnabled")
                                }

                            Divider()

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Test Notifications")
                                        .font(.body)
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Send a test notification to verify setup")
                                        .font(.caption)
                                        .foregroundColor(Theme.textTertiary)
                                }

                                Spacer()

                                Button(action: sendTestNotification) {
                                    if showingTestNotification {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Text("Send Test")
                                            .font(.footnote)
                                            .foregroundColor(Theme.accent)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(showingTestNotification)
                                .accessibilityLabel("Send test notification")
                                .accessibilityHint("Sends a test notification to verify your setup")
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Reminder Time")
                                    .font(.body)
                                    .foregroundColor(Theme.textPrimary)
                                Picker("Reminder time", selection: $notificationHour) {
                                    ForEach(6..<22) { hour in
                                        Text(formatHour(hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accessibilityLabel("Reminder time")
                                .accessibilityHint("Set when bill reminders are sent")
                                .onChange(of: notificationHour) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: "notificationHour")
                                }
                            }

                            Divider()

                            Button(action: openNotificationSettings) {
                                HStack {
                                    Text("Open Notification Settings")
                                        .font(.body)
                                        .foregroundColor(Theme.accent)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.square")
                                        .font(.caption)
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open notification settings")
                            .accessibilityHint("Opens system notification preferences")
                        }
                    }

                    // About Section
                    settingsSection(title: "ABOUT") {
                        VStack(alignment: .leading, spacing: Theme.spacing8) {
                            HStack {
                                Text("Chronicle")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("Never miss a bill.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textTertiary)
                            }
                            Divider()
                            Text("All data is stored locally on your device. No accounts, no cloud sync (yet).")
                                .font(.caption)
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                }
                .padding(Theme.spacing16)
            }
        }
        .frame(width: 400, height: 400)
        .background(Theme.background)
        .onAppear {
            notificationSoundEnabled = UserDefaults.standard.object(forKey: "notificationSoundEnabled") as? Bool ?? true
            notificationHour = UserDefaults.standard.object(forKey: "notificationHour") as? Int ?? 9
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(displayHour):00 \(period)"
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
                .tracking(Theme.trackingWide)

            VStack(alignment: .leading, spacing: Theme.spacing8) {
                content()
            }
            .padding(Theme.spacing12)
            .background(Theme.surface)
            .cornerRadius(Theme.radiusMedium)
        }
    }

    private func sendTestNotification() {
        showingTestNotification = true
        NotificationScheduler.shared.sendTestNotification()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingTestNotification = false
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}
