import SwiftUI

struct TaxExportView: View {
    @EnvironmentObject var billStore: BillStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var generatedReport: TaxExportService.TaxReport?
    @State private var isGenerating: Bool = false
    @State private var exportedURL: URL?
    @State private var showExportSuccess: Bool = false

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...currentYear).reversed()
    }

    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tax Export")
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
            }
            .padding(Theme.spacing16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing20) {
                    // Year selection
                    VStack(alignment: .leading, spacing: Theme.spacing8) {
                        Text("Tax Year")
                            .font(.footnote)
                            .foregroundColor(Theme.textSecondary)

                        Picker("", selection: $selectedYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .accessibilityLabel("Select tax year")
                    }

                    // Generate button
                    Button(action: generateReport) {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text("Generate Report")
                        }
                        .font(.body)
                        .foregroundColor(Theme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.spacing8)
                        .background(isGenerating ? Theme.textTertiary : Theme.accent)
                        .cornerRadius(Theme.radiusSmall)
                    }
                    .buttonStyle(.plain)
                    .disabled(isGenerating)
                    .accessibilityLabel("Generate tax report")
                    .accessibilityHint("Generates a tax report for the selected year")

                    // Report preview
                    if let report = generatedReport {
                        reportPreview(report)
                    }
                }
                .padding(Theme.spacing16)
            }

            if let _ = exportedURL {
                Divider()
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.success)
                    Text("Export saved to Documents/Chronicle/Tax Exports/\(selectedYear)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
                .padding(Theme.spacing12)
            }
        }
        .frame(width: 480, height: 520)
        .background(Theme.background)
    }

    private func reportPreview(_ report: TaxExportService.TaxReport) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing16) {
            // Summary
            HStack(spacing: Theme.spacing24) {
                summaryCard(
                    title: "Tax Deductible",
                    value: currencyFormatter.string(from: NSDecimalNumber(decimal: report.totalDeductible)) ?? "$0.00",
                    color: Theme.success
                )
                summaryCard(
                    title: "Reimbursable",
                    value: currencyFormatter.string(from: NSDecimalNumber(decimal: report.totalReimbursable)) ?? "$0.00",
                    color: Theme.accent
                )
                summaryCard(
                    title: "Bill Count",
                    value: "\(report.bills.count)",
                    color: Theme.textSecondary
                )
            }

            Divider()

            // By tag breakdown
            if !report.byTag.isEmpty {
                VStack(alignment: .leading, spacing: Theme.spacing8) {
                    Text("By Business Tag")
                        .font(.footnote)
                        .foregroundColor(Theme.textSecondary)

                    ForEach(Array(report.byTag.keys.sorted { $0.rawValue < $1.rawValue }), id: \.self) { tag in
                        HStack {
                            Image(systemName: tag.icon)
                                .font(.caption)
                                .foregroundColor(Theme.accent)
                                .frame(width: 16)
                            Text(tag.rawValue)
                                .font(.body)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text(currencyFormatter.string(from: NSDecimalNumber(decimal: report.byTag[tag] ?? 0)) ?? "$0.00")
                                .font(.body)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }

            // Export buttons
            HStack(spacing: Theme.spacing12) {
                Button(action: { exportCSV(report) }) {
                    HStack {
                        Image(systemName: "tablecells")
                        Text("Export CSV")
                    }
                    .font(.footnote)
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.spacing8)
                    .background(Theme.surface)
                    .cornerRadius(Theme.radiusSmall)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall)
                            .stroke(Theme.accent, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Export as CSV")
                .accessibilityHint("Exports tax report as CSV for TurboTax or QuickBooks")

                Button(action: { exportPDF(report) }) {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("Export PDF")
                    }
                    .font(.footnote)
                    .foregroundColor(Theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.spacing8)
                    .background(Theme.accent)
                    .cornerRadius(Theme.radiusSmall)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Export as PDF")
                .accessibilityHint("Exports tax report as PDF for printing or sharing")
            }
        }
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
    }

    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func generateReport() {
        isGenerating = true
        generatedReport = nil
        exportedURL = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            generatedReport = TaxExportService.shared.generateTaxReport(year: selectedYear, bills: billStore.bills)
            isGenerating = false
        }
    }

    private func exportCSV(_ report: TaxExportService.TaxReport) {
        if let url = TaxExportService.shared.exportToCSV(report: report) {
            exportedURL = url
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }

    private func exportPDF(_ report: TaxExportService.TaxReport) {
        if let url = TaxExportService.shared.exportToPDF(report: report) {
            exportedURL = url
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }
}
