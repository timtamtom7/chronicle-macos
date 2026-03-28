import SwiftUI
import PDFKit

struct InvoicePreviewView: View {
    let invoiceURL: URL
    @Environment(\.dismiss) private var dismiss

    @State private var pdfDocument: PDFDocument?
    @State private var isLoading: Bool = true
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // PDF View
            if isLoading {
                ProgressView("Loading invoice...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loadError {
                VStack(spacing: Theme.spacing8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(Theme.warning)
                    Text("Failed to load invoice")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let document = pdfDocument {
                PDFKitView(document: document)
            } else {
                Text("No content")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 700, height: 800)
        .background(Theme.background)
        .onAppear {
            loadPDF()
        }
    }

    private var toolbar: some View {
        HStack(spacing: Theme.spacing12) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.footnote)
                    .foregroundColor(Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer()

            Text("Invoice Preview")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            Spacer()

            if pdfDocument != nil {
                // Open in Preview app
                Button(action: openInPreview) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.footnote)
                        .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open in Preview")
                .accessibilityHint("Opens the invoice in the macOS Preview app")
            }
        }
        .padding(Theme.spacing12)
    }

    private func loadPDF() {
        isLoading = true
        loadError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let document = PDFDocument(url: invoiceURL)

            DispatchQueue.main.async {
                if document != nil {
                    self.pdfDocument = document
                } else {
                    self.loadError = "Could not open PDF file"
                }
                self.isLoading = false
            }
        }
    }

    private func openInPreview() {
        NSWorkspace.shared.open(invoiceURL)
    }
}

// MARK: - PDFKit Wrapper

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor.controlBackgroundColor
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}

// MARK: - Receipt Preview (simple image view)

struct ReceiptPreviewView: View {
    let receiptURL: URL
    @Environment(\.dismiss) private var dismiss

    @State private var image: NSImage?
    @State private var isLoading: Bool = true
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: Theme.spacing12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.footnote)
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")

                Spacer()

                Text("Receipt Preview")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Button(action: openInPreview) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.footnote)
                        .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open in Preview")
            }
            .padding(Theme.spacing12)

            Divider()

            // Image View
            if isLoading {
                ProgressView("Loading receipt...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loadError {
                VStack(spacing: Theme.spacing8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(Theme.warning)
                    Text("Failed to load receipt")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let image = image {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
            }
        }
        .frame(width: 600, height: 700)
        .background(Theme.background)
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        isLoading = true
        loadError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = NSImage(contentsOf: receiptURL)

            DispatchQueue.main.async {
                if loadedImage != nil {
                    self.image = loadedImage
                } else {
                    self.loadError = "Could not open image file"
                }
                self.isLoading = false
            }
        }
    }

    private func openInPreview() {
        NSWorkspace.shared.open(receiptURL)
    }
}
