# Chronicle for Android

Native Android companion app for Chronicle, built with **Kotlin** and **Jetpack Compose**.

## Goal

Achieve feature parity with the iOS companion app — a lightweight bill tracking experience
that stays in sync with the macOS app via a shared data container.

## Tech Stack

- **Language:** Kotlin 1.9+
- **UI:** Jetpack Compose with Material Design 3
- **Architecture:** MVVM with Clean Architecture layers
- **DI:** Hilt
- **Async:** Kotlin Coroutines + Flow
- **Storage:** SQLite via Room (local) + file-based sync with shared container

## Design Language

Material Design 3, using Chronicle's salmon color palette:

| Token          | Hex       | Use                     |
|----------------|-----------|-------------------------|
| Primary        | `#FF6B4A` | Accent, CTAs, highlights |
| Surface        | `#1C1C1E` | Dark backgrounds        |
| On Surface     | `#FFFFFF` | Primary text            |
| Secondary      | `#8E8E93` | Secondary text          |

Typography and component styling follow M3 guidelines adapted to Chronicle's brand identity.

## Data Sync

Two sync options under consideration:

1. **Shared iCloud container** — same `com.chronicle.shared` container used by the iOS app,
   accessible via the Android Storage Access Framework. Chronicle Android requests the
   container directly via device pairing.
2. **Google Drive App Folder** — each user gets a private app folder in their Google Drive.
   OAuth2-based, works across platforms without Apple dependency.

## Google Play Store

- **Package name:** `com.chronicle.android`
- **Release model:** Tied to macOS app release cycle (R1, R2, …)
- **Beta track:** Open beta for early testing before App Store release
- **Minimum SDK:** Android 8.0 (API 26)
- **Target SDK:** Android 14 (API 34)

## Feature Parity Checklist

- [ ] Bill list with due dates and amounts
- [ ] Local notifications (same scheduling as iOS)
- [ ] Sync via shared container / Google Drive
- [ ] Widgets (home screen, lock screen)
- [ ] Shortcuts / BII integration
- [ ] Widgets support (AOD on Samsung)

## Getting Started

```bash
# Requires Android Studio Hedgehog or later
cd android
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

> **Note:** The app is in early planning and stub stages. No functional code yet.
