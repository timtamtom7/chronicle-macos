import SwiftUI

/// Chronicle App Icon — Placeholder preview
/// This file renders the brand icon concept for visual reference.
/// Replace with actual asset catalog icons (Assets.xcassets/AppIcon.appiconset)
/// before shipping.
struct ChronicleAppIconView: View {
    var body: some View {
        ChronicleIconShape()
            .frame(width: 256, height: 256)
    }
}

struct ChronicleIconShape: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                // Background: warm cream rounded rect
                RoundedRectangle(cornerRadius: size * 0.18)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FAF9F7"), Color(hex: "F4F2EF")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Subtle border
                RoundedRectangle(cornerRadius: size * 0.18)
                    .stroke(Color(hex: "E8E5E0"), lineWidth: size * 0.01)

                // Drop shadow effect via layered rects
                RoundedRectangle(cornerRadius: size * 0.18)
                    .fill(Color.clear)
                    .shadow(color: .black.opacity(0.08), radius: size * 0.04, x: 0, y: size * 0.03)

                // Calendar document
                VStack(spacing: size * 0.04) {
                    // Calendar header bar
                    RoundedRectangle(cornerRadius: size * 0.03)
                        .fill(Color(hex: "E07A3A"))
                        .frame(width: size * 0.55, height: size * 0.1)

                    // Calendar lines (3 rows)
                    VStack(spacing: size * 0.03) {
                        HStack(spacing: size * 0.03) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: size * 0.015)
                                    .fill(Color(hex: "E8E5E0"))
                                    .frame(width: size * 0.1, height: size * 0.08)
                            }
                        }
                        HStack(spacing: size * 0.03) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: size * 0.015)
                                    .fill(Color(hex: "E8E5E0"))
                                    .frame(width: size * 0.1, height: size * 0.08)
                            }
                        }
                    }

                    // Checkmark badge
                    ZStack {
                        Circle()
                            .fill(Color(hex: "5A9A6E"))
                            .frame(width: size * 0.15, height: size * 0.15)

                        Image(systemName: "checkmark")
                            .font(.system(size: size * 0.08, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .padding(size * 0.18)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

#Preview {
    ChronicleAppIconView()
        .frame(width: 512, height: 512)
}
