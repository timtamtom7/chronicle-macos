import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins

struct InviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var householdService = HouseholdService.shared
    @ObservedObject private var inviteService = InviteService.shared

    let household: Household
    @State private var invite: HouseholdInvite?
    @State private var copied = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Invite to \(household.name)")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            Divider()

            // QR Code
            if let invite = invite {
                VStack(spacing: 16) {
                    qrCodeImage(for: invite)
                        .frame(width: 200, height: 200)

                    // Plain text code
                    HStack(spacing: 12) {
                        Text(invite.code)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                            .tracking(2)

                        Button(action: { copyCode(invite.code) }) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.body)
                                .foregroundColor(copied ? Theme.success : Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(copied ? "Copied" : "Copy code")
                    }

                    // Expires label
                    Text("Expires in 7 days")
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)
                }
            } else {
                // Generate invite button
                VStack(spacing: 16) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.textTertiary)

                    Text("No active invite")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)

                    Button("Generate Invite") {
                        if let member = householdService.currentMember {
                            invite = inviteService.createInvite(for: household.id, createdBy: member.id)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Generate invite code")
                }
            }

            Divider()

            // Actions
            VStack(spacing: 12) {
                // Copy link button
                if let invite = invite {
                    Button(action: { copyLink(invite) }) {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "link")
                            Text(copied ? "Link Copied!" : "Copy Invite Link")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(copied)
                    .accessibilityLabel("Copy invite link")
                }

                // Share sheet
                if let invite = invite {
                    ShareLink(item: invite.inviteLink) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Invite Link")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Share invite link")
                }

                // Revoke button
                if invite != nil {
                    Button("Revoke Invite", role: .destructive) {
                        inviteService.revokeInvite()
                        invite = nil
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Revoke invite")
                }
            }

            // Instructions
            Text("Scan the QR code or enter the invite code on another Mac to join this household.")
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            invite = inviteService.getInviteCode()
            if invite == nil, let member = householdService.currentMember {
                invite = inviteService.createInvite(for: household.id, createdBy: member.id)
            }
        }
    }

    @ViewBuilder
    private func qrCodeImage(for invite: HouseholdInvite) -> some View {
        if let cgImage = generateQRCode(from: invite.inviteLink) {
            Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: 200, height: 200)))
                .interpolation(.none)
                .resizable()
                .accessibilityLabel("QR code for household invite")
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: 64))
                .foregroundColor(Theme.textTertiary)
        }
    }

    private func generateQRCode(from string: String) -> CGImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = outputImage.transformed(by: transform)
        let context = CIContext()
        return context.createCGImage(scaled, from: scaled.extent)
    }

    private func copyCode(_ code: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }

    private func copyLink(_ invite: HouseholdInvite) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(invite.inviteLink, forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }
}
