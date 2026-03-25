import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var mainWindow: NSWindow!
    var billStore: BillStore?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        billStore = BillStore()
        setupMenu()
        setupStatusItem()
        setupPopover()
        setupMainWindow()

        // Hide dock icon - menu bar app only
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
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
                .environmentObject(billStore!)
        )
    }

    private func setupMainWindow() {
        let contentView = BillListView()
            .environmentObject(billStore!)

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
            popover.contentViewController = NSHostingController(
                rootView: ContentView(showMainWindow: showMainWindow)
                    .environmentObject(billStore!)
            )
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc func showMainWindow() {
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func addNewBill() {
        showMainWindow()
        // Post notification to open add sheet
        NotificationCenter.default.post(name: .openAddBillSheet, object: nil)
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

extension Notification.Name {
    static let openAddBillSheet = Notification.Name("openAddBillSheet")
    static let openEditBillSheet = Notification.Name("openEditBillSheet")
}
