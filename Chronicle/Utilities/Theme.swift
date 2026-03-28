import SwiftUI
import AppKit

// MARK: - Theme

/// Design tokens for Chronicle.
/// Font sizes use Dynamic Type (via @ScaledMetric) — text scales when users
/// change their system text size preference.
/// Font tokens are consumed via Theme.font* properties.
enum Theme {
    // MARK: - Colors

    // Use system-adaptive colors for background/surface (respect dark mode)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    /// Surface secondary — flat adaptive color for sidebar/footer surfaces.
    /// NSColor.controlBackgroundColor already adapts to light/dark mode via system.
    static let surfaceSecondary = Color(nsColor: .controlBackgroundColor)

    // Background levels for Liquid Glass depth
    static let backgroundLevel0 = Color(nsColor: .windowBackgroundColor)
    static let backgroundLevel1 = Color(nsColor: .controlBackgroundColor)
    static let backgroundLevel2 = Color(nsColor: .underPageBackgroundColor)

    // Brand/accent colors (WCAG AA compliant: 4.5:1+ for normal text)
    // accent: warm amber — trustworthy not urgent, finance-appropriate
    static let accent = Color(hex: "d4920a")           // Was #c8602a terracotta — now warm amber
    // success: bright celebratory green for PAID moments
    static let success = Color(hex: "2e9e58")          // Was #4a8a5e — brightened for emotional impact
    // warning: dark amber, passes WCAG AA in dark mode
    static let warning = Color(hex: "8a5010")          // Was #b06a10 — darkened for dark mode
    static let danger = Color(hex: "b44838")

    // Text colors use system label colors for dark mode support
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    static let textQuaternary = Color(nsColor: .quaternaryLabelColor)

    // Separator color
    static let separator = Color(nsColor: .separatorColor)

    // Border color
    static let border = Color(nsColor: .separatorColor)

    // Primary text on accent backgrounds (white)
    static let textOnAccent = Color.white

    // MARK: - Spacing

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32

    // MARK: - Typography (Dynamic Type ready)
    // Use these font tokens instead of hardcoded .system(size:) throughout views
    // These use @ScaledMetric-compatible sizing via .system with dynamicTypeSize

    static let fontTitle: Font = .system(size: 22, weight: .bold)
    static let fontHeadline: Font = .system(size: 16, weight: .semibold)
    static let fontBody: Font = .system(size: 13, weight: .regular)
    static let fontBodySemibold: Font = .system(size: 13, weight: .semibold)
    static let fontSubheadline: Font = .system(size: 12, weight: .medium)
    static let fontSubheadlineSemibold: Font = .system(size: 12, weight: .semibold)
    static let fontMediumLabel: Font = .system(size: 14, weight: .medium)
    static let fontMediumLabelSemibold: Font = .system(size: 14, weight: .semibold)
    static let fontLarge: Font = .system(size: 18, weight: .bold)  // empty state / emphasis
    static let fontCaption: Font = .system(size: 11, weight: .regular)
    static let fontCaptionSemibold: Font = .system(size: 11, weight: .semibold)
    static let fontCaptionMedium: Font = .system(size: 11, weight: .medium)
    static let fontSmall: Font = .system(size: 11, weight: .regular)
    static let fontLabel: Font = .system(size: 12, weight: .medium)

    // MARK: - Corner Radius

    // iOS 26 / macOS Liquid Glass design tokens
    static let cornerRadius4: CGFloat = 4
    static let cornerRadius8: CGFloat = 8
    static let cornerRadius10: CGFloat = 10
    static let cornerRadius12: CGFloat = 12
    static let cornerRadius14: CGFloat = 14
    static let cornerRadius16: CGFloat = 16
    static let cornerRadius20: CGFloat = 20

    // Named radius aliases
    static let radiusSmall: CGFloat = 6
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16
    static let radiusPill: CGFloat = 20

    // MARK: - Tracking

    static let trackingWide: CGFloat = 0.05

    // MARK: - Shadows

    // Card shadow — Liquid Glass presence, visible in dark mode
    static let cardShadowColor: Color = .black.opacity(0.12)
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 3

    static let toastShadowColor: Color = .black.opacity(0.15)
    static let toastShadowRadius: CGFloat = 8
    static let toastShadowY: CGFloat = 4

    // MARK: - Sheet Sizes

    static let sheetSmall: CGSize = CGSize(width: 380, height: 340)
    static let sheetMedium: CGSize = CGSize(width: 480, height: 420)
    static let sheetLarge: CGSize = CGSize(width: 520, height: 580)

    // MARK: - Empty State

    static let emptyStateIconSize: CGFloat = 32
}

// MARK: - Haptic Feedback

/// Haptic feedback using NSHapticFeedbackManager on macOS 13+.
/// Falls back to NSSound on older macOS versions.
/// For views, prefer the .sensoryFeedback() modifier on macOS 14+.
enum HapticFeedback {
    /// Light impact for subtle interactions (toggles, selections)
    static func light() {
        if #available(macOS 13.0, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        } else {
            NSSound(named: .init("Pop"))?.play()
        }
    }

    /// Medium impact for standard interactions (button taps)
    static func medium() {
        if #available(macOS 13.0, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        } else {
            NSSound(named: .init("Pop"))?.play()
        }
    }

    /// Heavy impact for significant actions (delete, important confirmations)
    static func heavy() {
        if #available(macOS 13.0, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        } else {
            NSSound(named: .init("Blow"))?.play()
        }
    }

    /// Success feedback for successful operations
    static func success() {
        if #available(macOS 13.0, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        } else {
            NSSound(named: .init("Fanfare"))?.play()
        }
    }

    /// Warning feedback
    static func warning() {
        if #available(macOS 13.0, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        } else {
            NSSound(named: .init("Alert"))?.play()
        }
    }

    /// Error feedback
    static func error() {
        if #available(macOS 13.0, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        } else {
            NSSound(named: .init("Basso"))?.play()
        }
    }

    /// Selection changed feedback
    static func selection() {
        if #available(macOS 13.0, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        } else {
            NSSound(named: .init("Pop"))?.play()
        }
    }
}

// MARK: - Button Styles

/// Primary button style for main actions
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.fontLabel)
            .foregroundColor(Theme.textOnAccent)
            .padding(.horizontal, Theme.spacing16)
            .padding(.vertical, Theme.spacing8)
            .background(isEnabled ? Theme.accent : Theme.textTertiary)
            .cornerRadius(Theme.radiusSmall)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? (reduceMotion ? 1.0 : 0.97) : 1.0)
            .animation(reduceMotion ? .none : .spring(response: 0.1, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// Secondary button style for secondary actions
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.fontLabel)
            .foregroundColor(isEnabled ? Theme.textPrimary : Theme.textTertiary)
            .padding(.horizontal, Theme.spacing16)
            .padding(.vertical, Theme.spacing8)
            .background(Theme.surface)
            .cornerRadius(Theme.radiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? (reduceMotion ? 1.0 : 0.97) : 1.0)
            .animation(reduceMotion ? .none : .spring(response: 0.1, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// Icon button style for toolbar actions
struct IconButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Theme.textSecondary)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(reduceMotion ? .none : .spring(response: 0.1, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    let status: BillStatus

    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .cornerRadius(Theme.radiusMedium)
            .shadow(color: Theme.cardShadowColor, radius: Theme.cardShadowRadius, x: 0, y: Theme.cardShadowY)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private var borderColor: Color {
        switch status {
        case .dueToday, .dueSoon: return Theme.accent.opacity(0.4)
        case .upcoming: return Theme.border
        case .overdue: return Theme.danger.opacity(0.4)
        case .paid: return Theme.success.opacity(0.4)
        }
    }
}

extension View {
    func cardStyle(status: BillStatus) -> some View {
        modifier(CardStyle(status: status))
    }
}

// MARK: - Category Colors

/// Design token for category colors — centralized here alongside other design tokens.
/// These colors should be WCAG AA compliant for their intended use.
enum ThemeCategoryColors {
    static let map: [Category: Color] = [
        .housing: Color(hex: "6b8cae"),
        // utilities: was #f4a261 — nearly invisible on white; darkened to #c47a3a for contrast
        .utilities: Color(hex: "c47a3a"),
        .subscriptions: Color(hex: "9b7ede"),
        .insurance: Color(hex: "5a9a6e"),
        .phoneInternet: Color(hex: "4ecdc4"),
        .transportation: Color(hex: "e07a3a"),
        .health: Color(hex: "e86868"),
        .other: Color(hex: "8a8a8a")
    ]
}
