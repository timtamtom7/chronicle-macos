import SwiftUI
import AppKit

// MARK: - Menu Bar Extra (macOS 14+ SwiftUI-native menu bar)
// This view is used when running with @main App struct on macOS 14+
// For compatibility with existing AppDelegate setup, use StatusBarController

@available(macOS 14.0, *)
struct MenuBarExtraContent: View {
    @ObservedObject var billStore: BillStore
    var onOpenMain: () -> Void
    var onQuit: () -> Void
    
    private var upcomingBills: [Bill] {
        Array(billStore.upcomingBills.prefix(5))
    }
    
    private var overdueBills: [Bill] {
        billStore.pastDue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Chronicle")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Overdue section
            if !overdueBills.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Overdue")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Text("\(overdueBills.count)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                ForEach(overdueBills.prefix(3)) { bill in
                    BillMenuRow(
                        bill: bill,
                        showPayButton: true,
                        onPay: { markPaid(bill) }
                    )
                }
                
                Divider()
            }
            
            // Upcoming section
            if upcomingBills.isEmpty && overdueBills.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("All caught up!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                Text("UPCOMING")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                ForEach(upcomingBills) { bill in
                    BillMenuRow(
                        bill: bill,
                        showPayButton: true,
                        onPay: { markPaid(bill) }
                    )
                }
            }
            
            Divider()
            
            // Actions
            Button(action: onOpenMain) {
                HStack {
                    Image(systemName: "arrow.up.forward.app")
                    Text("Open Chronicle")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            Button(action: onQuit) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 280)
        .onAppear {
            billStore.loadBills()
        }
    }
    
    private func markPaid(_ bill: Bill) {
        billStore.markPaid(bill, paid: true)
    }
}

// MARK: - Bill Menu Row

struct BillMenuRow: View {
    let bill: Bill
    var showPayButton: Bool = false
    var onPay: (() -> Void)?
    
    private var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: bill.dueDate).day ?? 0
    }
    
    private var statusColor: Color {
        if bill.isPaid {
            return .green
        } else if daysUntilDue < 0 {
            return .red
        } else if daysUntilDue <= 3 {
            return .orange
        } else {
            return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(categoryColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(bill.formattedAmount)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !bill.isPaid {
                VStack(alignment: .trailing, spacing: 2) {
                    if daysUntilDue == 0 {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if daysUntilDue < 0 {
                        Text("\(abs(daysUntilDue))d overdue")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("\(daysUntilDue)d")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if showPayButton {
                        Button("Pay") {
                            onPay?()
                        }
                        .font(.caption2)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
    
    private var categoryColor: Color {
        switch bill.category {
        case .housing: return .green
        case .utilities: return .blue
        case .subscriptions: return .purple
        case .insurance: return .orange
        case .phoneInternet: return .cyan
        case .transportation: return .pink
        case .health: return .red
        case .other: return .gray
        }
    }
}

// MARK: - Menu Bar Extra App (for macOS 14+)

// Uncomment below and remove AppDelegate to use SwiftUI-native MenuBarExtra
/*
@available(macOS 14.0, *)
struct ChronicleMenuBarApp: App {
    @StateObject private var billStore = BillStore.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarExtraContent(
                billStore: billStore,
                onOpenMain: { NSApp.activate() },
                onQuit: { NSApp.terminate(nil) }
            )
        } label: {
            Image(systemName: "dollarsign.circle.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
*/

// MARK: - Status Bar Controller (for macOS 13 compatibility with MenuBarExtra-like behavior)

class StatusBarController {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var billStore: BillStore
    private var eventMonitor: Any?
    
    init(billStore: BillStore) {
        self.billStore = billStore
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "dollarsign.circle.fill", accessibilityDescription: "Chronicle")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 400)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarPopoverContent(billStore: billStore)
        )
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.popover?.performClose(nil)
            }
        }
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            Task { @MainActor in
                self.billStore.loadBills()
            }
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func updateBadge(overdueCount: Int) {
        if let button = statusItem?.button {
            if overdueCount > 0 {
                button.image = NSImage(systemSymbolName: "dollarsign.circle.fill", accessibilityDescription: "Chronicle - \(overdueCount) overdue")
            } else {
                button.image = NSImage(systemSymbolName: "dollarsign.circle.fill", accessibilityDescription: "Chronicle")
            }
        }
    }
}

// MARK: - Menu Bar Popover Content (SwiftUI)

struct MenuBarPopoverContent: View {
    @ObservedObject var billStore: BillStore
    
    private var upcomingBills: [Bill] {
        Array(billStore.upcomingBills.prefix(5))
    }
    
    private var overdueBills: [Bill] {
        billStore.pastDue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Chronicle")
                    .font(.headline)
                Spacer()
                Button(action: {
                    if #available(macOS 14.0, *) {
                        NSApp.activate()
                    } else {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Overdue section
            if !overdueBills.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Overdue")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Text("\(overdueBills.count)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                ForEach(overdueBills.prefix(3)) { bill in
                    BillMenuRow(
                        bill: bill,
                        showPayButton: true,
                        onPay: { markPaid(bill) }
                    )
                }
                
                Divider()
            }
            
            // Upcoming section
            if upcomingBills.isEmpty && overdueBills.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("All caught up!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                Text("UPCOMING")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                ForEach(upcomingBills) { bill in
                    BillMenuRow(
                        bill: bill,
                        showPayButton: true,
                        onPay: { markPaid(bill) }
                    )
                }
            }
            
            Spacer()
            
            Divider()
            
            Button(action: { NSApp.terminate(nil) }) {
                HStack {
                    Spacer()
                    Text("Quit Chronicle")
                        .font(.caption)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
        }
        .frame(width: 280)
    }
    
    private func markPaid(_ bill: Bill) {
        billStore.markPaid(bill, paid: true)
    }
}
