# Chronicle — Onboarding Guide

Chronicle's onboarding is warm, brief, and action-oriented. It should feel like being handed a well-organized planner — immediately useful, no confusion. The flow consists of 4 screens delivered as a SwiftUI sheet or tabbed walkthrough.

**Tone:** Encouraging, clear, never patronizing. "You're in control of your bills."

---

## Screen 1 — "Your Bills, Organized"

**Concept illustration:** A warm-toned scene showing a calendar page with bills appearing as small cards sliding into place. One bill is highlighted with a terracotta accent, a checkmark showing it's been tracked.

**Headline:** "Never miss a due date"

**Body:** "Chronicle tracks your recurring bills so you always know what's coming. Add your first bill in seconds."

**Primary CTA:** "Add Your First Bill →"

**Secondary:** "Skip for now"

**Visual elements:**
- Warm cream background (`#FAF9F7`)
- Terracotta (`#E07A3A`) accent on the highlighted bill card
- Soft illustration of a calendar page with a few "bill" cards
- Small checkmark badge on a paid bill (success green `#5A9A6E`)

---

## Screen 2 — "Stay Ahead, Not Stressed"

**Concept illustration:** A simple timeline or calendar strip showing upcoming bills at a glance. Shows the "due soon" and "paid" states clearly. A small notification bell icon is highlighted.

**Headline:** "Know what's coming"

**Body:** "Set reminders a few days before bills are due. Chronicle sends you a gentle nudge — no spam, just clarity."

**Key points (illustrated with small icons):**
- 🔔 "Remind me 1–3 days before"
- ✅ "Mark as paid with one tap"
- 📊 "See your monthly spending at a glance"

**Primary CTA:** "Continue →"

---

## Screen 3 — "Organize Your Way"

**Concept illustration:** A grid of bill "templates" — utility, subscription, rent, loan — as small cards. Shows the categorization/tagging concept. Visual grouping by category with color-coded labels.

**Headline:** "Templates save time"

**Body:** "Most bills repeat every month. Create a template once, and Chronicle fills it in for you going forward."

**Visual elements:**
- 4–6 small template cards: 🏠 Rent, ⚡ Utilities, 📱 Subscriptions, 🚗 Car, 💳 Loan, 📄 Other
- Each card has a subtle category color
- "+" button to add a new template

**Primary CTA:** "Set Up Templates →"

---

## Screen 4 — "You're All Set"

**Concept illustration:** A clean, celebratory scene with the Chronicle icon prominently displayed. A few bill cards are shown in the background, all checked off. Warm, calm, not overly flashy.

**Headline:** "Your bills are ready to track"

**Body:** "Chronicle is running quietly in your menu bar. Click the icon to see your bills, add new ones, or check your budget."

**Key callouts:**
- 🍎 "Find Chronicle in your menu bar"
- ⌨️ "Press **⌘B** to add a new bill quickly"
- 📊 "Check the Overview tab for spending insights"

**Primary CTA:** "Open Chronicle"

---

## Implementation Notes

- Onboarding should only show on first launch (use `UserDefaults` flag `hasSeenOnboarding`)
- Use a `TabView` with 4 tabs, or a `VStack` with page dots
- Each screen should fade/slide in from the right
- Use `SemanticUI` colors from `Theme.swift` — no hardcoded hex values in UI code
- Illustrations can be SF Symbols compositions + `Shape` drawings in SwiftUI (no external assets required for placeholder)
