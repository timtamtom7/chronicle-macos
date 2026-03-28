import SwiftUI
import AppKit

struct ShareView: View {
    @EnvironmentObject var billStore: BillStore
    @Binding var isPresented: Bool

    @State private var selectedRange: ShareRange = .upcoming
    @State private var includePaid = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Share Bills")
                    .font(Theme.fontHeadline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(Theme.fontLabel)
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .accessibilityHint("Closes the share view")
            }
            .padding(Theme.spacing16)

            Divider()

            VStack(spacing: Theme.spacing16) {
                VStack(alignment: .leading, spacing: Theme.spacing8) {
                    Text("Share Range")
                        .font(Theme.fontLabel)
                        .foregroundColor(Theme.textSecondary)

                    Picker("", selection: $selectedRange) {
                        ForEach(ShareRange.allCases, id: \.self) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Share range")
                    .accessibilityHint("Select which bills to include in the share")
                }

                Toggle("Include paid bills", isOn: $includePaid)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Include paid bills")
                    .accessibilityHint("Toggle to include or exclude paid bills from the share")

                Divider()

                VStack(spacing: Theme.spacing8) {
                    shareButton(
                        title: "Share as Text",
                        subtitle: "Plain text summary",
                        icon: "text.alignleft"
                    ) {
                        shareAsText()
                    }

                    shareButton(
                        title: "Share as PDF",
                        subtitle: "Formatted document",
                        icon: "doc.richtext"
                    ) {
                        shareAsPDF()
                    }

                    shareButton(
                        title: "Copy Summary to Clipboard",
                        subtitle: "Plain text in clipboard",
                        icon: "doc.on.clipboard"
                    ) {
                        copyToClipboard()
                    }
                }
            }
            .padding(Theme.spacing16)
        }
        .frame(width: 380, height: 340)
        .background(Theme.background)
    }

    private func shareButton(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Theme.fontLabel)
                        .foregroundColor(Theme.textPrimary)
                    Text(subtitle)
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textTertiary)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12))
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
        .buttonStyle(.plain)
    }

    private var billsToShare: [Bill] {
        let all = billStore.bills
        let filtered: [Bill]

        switch selectedRange {
        case .upcoming:
            filtered = all.filter { !$0.isPaid }
        case .thisMonth:
            let calendar = Calendar.current
            let now = Date()
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
                filtered = []
                break
            }
            filtered = all.filter { $0.dueDate >= monthStart && $0.dueDate <= monthEnd }
        case .all:
            filtered = all
        }

        return includePaid ? filtered : filtered.filter { !$0.isPaid }
    }

    private func shareAsText() {
        let text = ShareService.shared.generateBillSummary(for: billsToShare)
        let picker = NSSharingServicePicker(items: [text])
        if let contentView = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        }
    }

    private func shareAsPDF() {
        guard let pdfURL = ShareService.shared.generatePDF(for: billsToShare, title: "Bill Summary") else { return }
        let picker = NSSharingServicePicker(items: [pdfURL])
        if let contentView = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        }
    }

    private func copyToClipboard() {
        let text = ShareService.shared.generateBillSummary(for: billsToShare)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        isPresented = false
    }
}

enum ShareRange: String, CaseIterable {
    case upcoming
    case thisMonth
    case all

    var title: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .thisMonth: return "This Month"
        case .all: return "All Time"
        }
    }
}
