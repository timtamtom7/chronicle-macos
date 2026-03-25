# Chronicle — Brand Guide

## 1. Concept & Vision

Chronicle is a bill-tracking app that brings calm clarity to financial obligations. It feels like a well-kept paper ledger — warm, trustworthy, and organized — but with the intelligence of a modern app. The brand evokes reliability and gentle control: you know exactly what's due and when, without anxiety.

**App type:** Menu bar utility (LSUIElement)
**Core function:** Track recurring bills, due dates, budgets, and payment history.

---

## 2. Icon Concept — "The Terracotta Ledger"

### Visual Description

A warm terracotta rounded rectangle (suggesting a card or ledger page) containing a stylized calendar/document motif. Inside, a subtle checkmark or circle marks a paid bill. The overall shape is soft and organic — not a rigid grid, but a flowing document with warmth.

**Key elements:**
- **Shape:** Rounded rectangle with soft corners (approx. 82% of canvas), representing a document/card
- **Primary glyph:** A simplified calendar page with a folded corner (classic document iconography)
- **Accent mark:** A small circle or checkmark in the accent color, suggesting completion/paid status
- **Background:** Warm cream-to-terracotta gradient or solid warm background
- **Depth:** Very subtle drop shadow to lift the icon off the surface

### Color Palette

| Role | Hex | Usage |
|------|-----|-------|
| Background Warm | `#FAF9F7` | Icon background base |
| Primary Accent | `#E07A3A` | Terracotta — due dates, CTAs, calendar mark |
| Secondary Accent | `#F4A261` | Lighter terracotta — highlights, gradients |
| Surface | `#FFFFFF` | Card/document white |
| Success | `#5A9A6E` | Paid/healthy status |
| Warning | `#E09A3A` | Due soon |
| Danger | `#C45A4A` | Overdue |
| Text Primary | `#2A2A2A` | Headings, amounts |
| Text Secondary | `#7A7A7A` | Labels, dates |
| Border | `#E8E5E0` | Dividers, card borders |

### Typography

- **Primary font:** SF Pro Rounded (rounded variant of SF Pro, Apple system)
- **Headings:** SF Pro Rounded Medium, 15–18pt
- **Body:** SF Pro Text Regular, 13–14pt
- **Numbers/amounts:** SF Pro Rounded Medium (tabular figures for alignment)
- **Fallback:** `.systemFont` with `design: .rounded` in SwiftUI

### Visual Motif

**The Calendar Document** — bills exist in time, tracked on a calendar. The icon bridges the gap between a ledger (old-world trust) and a modern card UI. The terracotta accent color carries warmth — this isn't a cold finance app, it's a personal assistant that cares about your peace of mind.

### Icon at Different Sizes

| Size | Rendering |
|------|-----------|
| **16×16** | Smallest — terracotta rounded rect with a single dot (paid indicator). Minimal detail. |
| **32×32** | Rounded rect with faint calendar lines and one checkmark. Recognizable as a document/bill icon. |
| **64×64** | Full calendar-page motif visible, folded corner, checkmark in accent. |
| **128×128** | Calendar grid lines appear faintly. Soft shadow gives depth. |
| **256×256** | Calendar icon with date number "15" faintly visible. Subtle gradient on the terracotta background. |
| **512×512** | Rich detail: calendar page, fold shadow, checkmark, faint ruled lines, shadow at bottom edge. |
| **1024×1024** | Full brand experience: warm gradient background, large calendar document with folded corner, checkmark badge, subtle ruled-line texture on the document. |

---

## 3. Placeholder Icon (SwiftUI)

The placeholder icon is a simple SwiftUI view that renders the icon concept for preview purposes. Place in `Chronicle/Views/AppIconView.swift`.

```swift
import SwiftUI

struct ChronicleAppIcon: View {
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
                
                // Shadow beneath the card
                RoundedRectangle(cornerRadius: size * 0.18)
                    .fill(Color(hex: "E07A3A").opacity(0.0))
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
```

---

## 4. Secondary Icon Elements

- **Menu bar icon:** Small (18×18pt): terracotta rounded square with a white checkmark. Simple, scannable.
- **Tab/feature icons:** SF Symbols — `calendar`, `doc.text`, `chart.bar`, `dollarsign.circle`, `clock`
- **Empty state illustrations:** Warm cream background, terracotta line-art illustrations of documents and calendars

---

## 5. Spatial System

| Token | Value |
|-------|-------|
| Spacing XS | 4pt |
| Spacing SM | 8pt |
| Spacing MD | 12pt |
| Spacing LG | 16pt |
| Spacing XL | 24pt |
| Corner Radius SM | 6pt |
| Corner Radius MD | 12pt |
| Corner Radius LG | 16pt |
