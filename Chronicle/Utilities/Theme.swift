import SwiftUI

enum Theme {
    // MARK: - Colors

    // Use system-adaptive colors for background/surface (respect dark mode)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let surfaceSecondary = Color(nsColor: .controlBackgroundColor).opacity(0.8)

    // Brand/accent colors stay consistent
    static let accent = Color(hex: "e07a3a")
    static let accentSecondary = Color(hex: "f4a261")
    static let success = Color(hex: "5a9a6e")
    static let warning = Color(hex: "e09a3a")
    static let danger = Color(hex: "c45a4a")

    // Text colors use system label colors for dark mode support
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    static let border = Color(nsColor: .separatorColor)

    // MARK: - Spacing

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32

    // MARK: - Radius

    static let radiusSmall: CGFloat = 6
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16

    // MARK: - Shadows

    static func cardShadow() -> some View {
        Color.black.opacity(0.05)
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
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
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
