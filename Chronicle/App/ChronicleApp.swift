import AppKit
import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var mainWindow: NSWindow!
    var billStore: BillStore!
    var notificationDelegate: NotificationDelegate!

    private var badgeUpdateTimer: Timer?

    nonisolated override init() {
        // Nonisolated init - only setup things that don't need MainActor
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        billStore = BillStore.shared

        // R16: Initialize subscription service on launch
        if #available(macOS 13.0, *) {
            Task {
                await SubscriptionService.shared.refreshStatus()
            }
        }

        // Setup notifications
        setupNotifications()

        // Start overdue checker
        OverdueChecker.shared.start()

        // Setup menu bar and windows
        setupMenu()
        setupStatusItem()
        setupPopover()
        setupMainWindow()

        // Show dock icon - regular app with menu bar extra
        NSApp.setActivationPolicy(.regular)

        // Listen for bill changes to update badge
        NotificationCenter.default.addObserver(
            forName: .billsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateBadge() }
        }

        // Update badge on launch
        updateBadge()

        // Start badge update timer
        badgeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateBadge() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    // MARK: - Notifications Setup

    private func setupNotifications() {
        notificationDelegate = NotificationDelegate()
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // Register notification category with actions
        let markPaidAction = UNNotificationAction(
            identifier: "MARK_PAID",
            title: "Mark Paid",
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze 1 Day",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: "BILL_REMINDER",
            actions: [markPaidAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])

        // Check authorization status
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                let granted = settings.authorizationStatus == .authorized
                UserDefaults.standard.set(granted, forKey: "notificationPermissionGranted")

                if !granted && settings.authorizationStatus == .notDetermined {
                    // First launch — request permission
                    NotificationScheduler.shared.requestAuthorization { _ in }
                } else if settings.authorizationStatus == .denied {
                    // Already denied — show in-app banner will be handled in views
                    NotificationCenter.default.post(name: .notificationPermissionDenied, object: nil)
                }

                // Reschedule all notifications on launch
                NotificationScheduler.shared.rescheduleAllNotifications(bills: self?.billStore.bills ?? [])
            }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                if settings.authorizationStatus == .notDetermined {
                    NotificationScheduler.shared.requestAuthorization { granted in
                        Task { @MainActor in
                            if !granted {
                                NotificationCenter.default.post(name: .notificationPermissionDenied, object: nil)
                            }
                        }
                    }
                } else if settings.authorizationStatus == .denied {
                    NotificationCenter.default.post(name: .notificationPermissionDenied, object: nil)
                }
            }
        }
    }

    // MARK: - Badge

    private func updateBadge() {
        let overdueCount = billStore.pastDue.count
        NotificationScheduler.shared.updateBadgeCount(overdueCount: overdueCount)

        // Update status item badge
        if let button = statusItem.button {
            if overdueCount > 0 {
                button.image = NSImage(systemSymbolName: "calendar.badge.exclamationmark", accessibilityDescription: "Chronicle - \(overdueCount) overdue")
            } else {
                let todayBills = billStore.bills.filter { $0.status() == .dueToday && !$0.isPaid }
                if !todayBills.isEmpty {
                    button.image = NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "Chronicle - due today")
                } else {
                    button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Chronicle")
                }
            }
        }
    }

    // MARK: - Menu Bar

    private func setupMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Chronicle", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Chronicle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Bill", action: #selector(addNewBill), keyEquivalent: "n")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Show All Bills", action: #selector(showMainWindow), keyEquivalent: "1")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Chronicle")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 480, height: 400)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: ContentView(showMainWindow: showMainWindow)
                .environmentObject(billStore)
        )
    }

    private func setupMainWindow() {
        let contentView = MainTabView()
            .environmentObject(billStore)

        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        mainWindow.title = "Chronicle"
        mainWindow.contentViewController = NSHostingController(rootView: contentView)
        mainWindow.minSize = NSSize(width: 560, height: 400)
        mainWindow.center()
        mainWindow.isReleasedWhenClosed = false
    }

    // MARK: - Actions

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Refresh content before showing
            billStore.loadBills()
            updateBadge()
            popover.contentViewController = NSHostingController(
                rootView: ContentView(showMainWindow: showMainWindow)
                    .environmentObject(billStore)
            )
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc func showMainWindow() {
        billStore.loadBills()
        updateBadge()
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func addNewBill() {
        showMainWindow()
        NotificationCenter.default.post(name: .openAddBillSheet, object: nil)
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    // MARK: - URL Scheme Handling

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "chronicle" else { return }

        if url.host == "join" || url.path.hasPrefix("/join") {
            // Parse invite code from query or path
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            var inviteCode: String?

            // Check query parameter: chronicle://join?code=XXXXXXXX
            if let code = components?.queryItems?.first(where: { $0.name == "code" })?.value {
                inviteCode = code
            } else {
                // Check path: chronicle://join/XXXXXXXX
                let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if !path.isEmpty && path.count == 8 {
                    inviteCode = path
                }
            }

            if let code = inviteCode {
                Task { @MainActor in
                    let success = InviteService.shared.joinWithCode(code)
                    if success {
                        NotificationCenter.default.post(name: .householdDidChange, object: nil)
                        showMainWindow()
                    }
                }
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openAddBillSheet = Notification.Name("openAddBillSheet")
    static let openEditBillSheet = Notification.Name("openEditBillSheet")
    static let notificationPermissionDenied = Notification.Name("notificationPermissionDenied")
}
