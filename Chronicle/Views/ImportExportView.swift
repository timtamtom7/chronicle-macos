import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImportExportView: View {
    @EnvironmentObject var billStore: BillStore
    @Binding var isPresented: Bool

    @State private var showImportPanel = false
    @State private var showExportSuccess = false
    @State private var exportSuccessMessage = ""
    @State private var importResult: CSVImportService.ImportResult?
    @State private var showImportResult = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import & Export")
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
                .accessibilityHint("Closes the import export view")
            }
            .padding(Theme.spacing16)

            Divider()

            ScrollView {
                VStack(spacing: Theme.spacing16) {
                    // Import Section
                    importSection

                    Divider()

                    // Export Section
                    exportSection
                }
                .padding(Theme.spacing16)
            }
        }
        .frame(width: 480, height: 420)
        .background(Theme.background)
        .sheet(isPresented: $showImportResult) {
            ImportResultSheet(isPresented: $showImportResult, result: importResult)
        }
        .fileImporter(
            isPresented: $showImportPanel,
            allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing8) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.accent)
                Text("Import Bills")
                    .font(.callout)
                    .foregroundColor(Theme.textPrimary)
            }

            Text("Import bills from a CSV file. The file should have columns for name, amount, and due date.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)

            Button(action: { showImportPanel = true }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 12))
                    Text("Choose CSV File")
                        .font(.footnote)
                }
                .foregroundColor(Theme.textOnAccent)
                .padding(.horizontal, Theme.spacing16)
                .padding(.vertical, 8)
                .background(Theme.accent)
                .cornerRadius(Theme.radiusSmall)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose CSV file")
            .accessibilityHint("Opens a file picker to select a CSV file to import bills from")

            VStack(alignment: .leading, spacing: 4) {
                Text("CSV Format:")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text("name, amount, currency, due_date, due_day, recurrence, category, notes")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(.top, Theme.spacing4)
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.accent)
                Text("Export Data")
                    .font(.callout)
                    .foregroundColor(Theme.textPrimary)
            }

            Text("Export your bills and payment history in various formats.")
                .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)

            VStack(spacing: Theme.spacing8) {
                exportButton(
                    title: "Export All Bills (JSON)",
                    subtitle: "Full backup with all details",
                    icon: "doc.fill",
                    isPrimary: true,
                    action: exportAllBillsJSON
                )

                exportButton(
                    title: "Export Bills (CSV)",
                    subtitle: "Spreadsheet-compatible format",
                    icon: "tablecells",
                    isPrimary: false,
                    action: exportBillsCSV
                )

                exportButton(
                    title: "Export Payment History (CSV)",
                    subtitle: "All payment records",
                    icon: "clock",
                    isPrimary: false,
                    action: exportPaymentsCSV
                )
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func exportButton(title: String, subtitle: String, icon: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundColor(isPrimary ? Theme.textOnAccent : Theme.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.footnote)
                        .foregroundColor(isPrimary ? Theme.textOnAccent : Theme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isPrimary ? Theme.textOnAccent.opacity(0.8) : Theme.textTertiary)
                }

                Spacer()

                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 12))
                    .foregroundColor(isPrimary ? Theme.textOnAccent.opacity(0.8) : Theme.textTertiary)
            }
            .padding(Theme.spacing12)
            .background(isPrimary ? Theme.accent : Theme.surface)
            .cornerRadius(Theme.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(isPrimary ? Color.clear : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                let content = try String(contentsOf: url, encoding: .utf8)
                let importResult = CSVImportService.shared.parseCSV(content)
                self.importResult = importResult

                for bill in importResult.importedBills {
                    billStore.addBill(bill)
                }

                showImportResult = true
            } catch {
                print("Import error: \(error)")
            }

        case .failure(let error):
            print("File picker error: \(error)")
        }
    }

    private func exportAllBillsJSON() {
        Task {
            do {
                let url = try await ExportService.shared.exportData()
                ExportService.shared.shareExport(at: url)
            } catch {
                print("Export error: \(error)")
            }
        }
    }

    private func exportBillsCSV() {
        if let url = ExportService.shared.exportToCSV(bills: billStore.bills) {
            ExportService.shared.shareExport(at: url)
        }
    }

    private func exportPaymentsCSV() {
        let payments = billStore.allPaymentRecords()
        if let url = ExportService.shared.exportPaymentHistory(payments: payments, bills: billStore.bills) {
            ExportService.shared.shareExport(at: url)
        }
    }
}

// MARK: - Import Result Sheet

struct ImportResultSheet: View {
    @Binding var isPresented: Bool
    let result: CSVImportService.ImportResult?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Import Result")
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
                .accessibilityHint("Closes the import result view")
            }
            .padding(Theme.spacing16)

            Divider()

            if let result = result {
                VStack(spacing: Theme.spacing16) {
                    HStack(spacing: Theme.spacing16) {
                        VStack {
                            Text("\(result.successCount)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.success)
                            Text("Imported")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                        }

                        if result.failedCount > 0 {
                            VStack {
                                Text("\(result.failedCount)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.danger)
                                Text("Skipped")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }

                    if !result.errors.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.spacing4) {
                            Text("Warnings:")
                                .font(.footnote)
                                .foregroundColor(Theme.textSecondary)
                            ScrollView {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(result.errors.prefix(5), id: \.self) { error in
                                        Text("• \(error)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(Theme.textTertiary)
                                    }
                                }
                            }
                            .frame(maxHeight: 100)
                        }
                    }
                }
                .padding(Theme.spacing16)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(Theme.textOnAccent)
                    .padding(.horizontal, Theme.spacing16)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .cornerRadius(Theme.radiusSmall)
                    .accessibilityLabel("Done")
                    .accessibilityHint("Closes the import result view")
            }
            .padding(Theme.spacing16)
        }
        .frame(width: 340, height: result?.errors.isEmpty == false ? 280 : 200)
        .background(Theme.background)
    }
}
