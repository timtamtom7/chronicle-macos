# Chronicle Web (PWA)

A **Progressive Web App** wrapper around Chronicle's web dashboard, enabling access from
any browser on Windows, Linux, and macOS without installing a native app.

## What This Is

The web dashboard (built in R14) wrapped as an installable PWA:

- Works offline via a service worker (app shell cached on first load)
- Add to home screen / desktop shortcut
- Push notifications via Web Push API
- Same feature set as the macOS app — bill list, reminders, spending charts

## Tauri / Electron Packaging

For a native feel on Windows and Linux, this PWA can be wrapped:

- **Tauri (recommended):** Rust-based, small binary (~3 MB), system-native look,
  direct access to system notifications and tray icon. Chronicle's macOS app is
  already Tauri-based.
- **Electron (fallback):** Larger bundle (~150 MB), more familiar tooling, but
  heavier. Useful if the team has existing Electron expertise.

Both would embed the same web app, so development is a single codebase.

## Architecture

```
platforms/web/
├── index.html          # PWA entry point
├── manifest.json       # Web app manifest (icons, theme, display mode)
├── service-worker.js   # Offline-first caching strategy
├── styles.css          # Minimal styling (app shell)
└── README.md
```

The web app itself lives in the existing `chronicle-web/` directory. This directory
contains only the PWA wrapper and packaging configuration.

## Browser Support

- Chrome / Edge 90+
- Firefox 90+
- Safari 15+
- No IE11 support

## Development

```bash
# Serve locally (any static server)
npx serve .
# or
python -m http.server 8080
```

## Sync

Relies on the same sync infrastructure as the macOS app:
- iCloud Web (CloudKit JS API) for Apple users
- Google Sign-In + Drive API as cross-platform fallback
