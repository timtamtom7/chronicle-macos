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
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 11))
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
        .frame(width: 480, height: 400)
        .background(Theme.background)
        .sheet(isPresented: $showingAddSheet) {
            AddBillSheet(isPresented: $showingAddSheet)
        }
        .sheet(item: $selectedBill) { bill in
            AddBillSheet(isPresented: .constant(true), editingBill: bill)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Spacer()

            // Quick actions
            HStack(spacing: Theme.spacing12) {
                // Pay all due today button
                if !billStore.upcomingBills.filter({ $0.status() == .dueToday }).isEmpty {
                    Button(action: payAllDueToday) {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 11))
                            Text("Pay All Due")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Theme.success)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { showSettingsSheet = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button(action: { showTemplatesSheet = true }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Templates")

                Button(action: { showBudgetSheet = true }) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Budgets")

                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.accent)
                .help("Add Bill")
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

            Text("No upcoming bills")
                .font(.system(size: 14, weight: .medium))
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
                .font(.system(size: 13))
                .foregroundColor(Theme.warning)

            Text("Notifications are off. Enable in System Settings to get reminders.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Button(action: openSystemSettings) {
                Text("Open Settings")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.accent)
            }
            .buttonStyle(.plain)

            Button(action: { showPermissionBanner = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing8)
        .background(Theme.warning.opacity(0.1))
    }

    private var monthlyOverview: some View {
        VStack(spacing: Theme.spacing8) {
            HStack {
                Text("Monthly Overview")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: showMainWindow) {
                    Text("View All")
                        .font(.system(size: 10, weight: .medium))
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
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
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
                .font(.system(size: 14, weight: .medium))
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
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
                    // Notifications Section
                    settingsSection(title: "NOTIFICATIONS") {
                        VStack(alignment: .leading, spacing: Theme.spacing12) {
                            Toggle("Notification Sound", isOn: $notificationSoundEnabled)
                                .toggleStyle(.switch)
                                .onChange(of: notificationSoundEnabled) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: "notificationSoundEnabled")
                                }

                            Divider()

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Test Notifications")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Send a test notification to verify setup")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textTertiary)
                                }

                                Spacer()

                                Button(action: sendTestNotification) {
                                    if showingTestNotification {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Text("Send Test")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Theme.accent)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(showingTestNotification)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notification Time")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Reminders are sent at 9:00 AM local time")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textTertiary)
                            }

                            Divider()

                            Button(action: openNotificationSettings) {
                                HStack {
                                    Text("Open Notification Settings")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.accent)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.square")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
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
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textTertiary)
                            }
                            Divider()
                            Text("All data is stored locally on your device. No accounts, no cloud sync (yet).")
                                .font(.system(size: 11))
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
        }
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .tracking(0.05)

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
