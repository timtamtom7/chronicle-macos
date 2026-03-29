# Chronicle R19 Security Hardening

## Overview

Chronicle R19 introduces comprehensive privacy and security hardening. This document details the security posture, entitlements, and runtime protections.

---

## Entitlements

Chronicle uses the following App Sandbox entitlements:

| Entitlement | Value | Purpose |
|-------------|-------|---------|
| `com.apple.security.app-sandbox` | `true` | App Sandbox isolation |
| `com.apple.security.network.client` | `true` | iCloud sync + localhost API server |
| `com.apple.security.files.user-selected.read-write` | `true` | Import/export user files |
| `com.apple.security.files.documents.read-write` | `true` | Export to ~/Documents/Chronicle/Exports |
| `com.apple.security.keychain-access-groups` | `$(AppIdentifierPrefix)com.chronicle.macos` | Secure key storage for API key + AES-256 key |

---

## Hardened Runtime

**Status:** Enabled (`ENABLE_HARDENED_RUNTIME: YES`)

The Hardened Runtime provides runtime protections against code injection and library hijacking:

- **Library Validation:** Prevents loading unsigned dynamic libraries
- **Hardened Runtime:** Enabled for all build configurations
- **Debugging:** Disabled in Release builds (`DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`)

---

## Data Encryption (AES-256)

### Implementation

- **Algorithm:** AES-256-GCM (authenticated encryption)
- **Key Size:** 256 bits
- **Key Storage:** macOS Keychain (`kSecAttrAccessibleWhenUnlocked`)
- **Key Management:** Generated on first launch; stored securely in Keychain; never in plain text

### What's Encrypted

| Field | Encrypted | Rationale |
|-------|-----------|-----------|
| Bill notes | ✅ AES-256-GCM | May contain sensitive financial info |
| Encryption key | ✅ Keychain | Never stored in plain text |
| API key | ✅ Keychain | Secure storage via APIKeyService |

### Encryption Flow

```
App Launch → EncryptionService.initializeKey()
           → Loads/generates AES-256 key from Keychain
           → Key stored in memory for session

Write Bill → encrypt(notes) → base64 → SQLite
Read Bill  → decrypt(notes) → plain text → Bill object
```

---

## Privacy Lock

### Features

- **Password Protection:** SHA-256 hashed password stored in Keychain
- **Timeout:** Configurable (default 5 minutes)
- **Auto-lock:** Engages after timeout or on app background

### Password Storage

- Password is **never** stored in plain text
- Salt: 32 bytes of cryptographically random data
- Hash: SHA-256(password + salt)
- Both stored in macOS Keychain

---

## TOTP 2FA (API Access)

### Implementation

- **Standard:** RFC 6238 TOTP
- **Algorithm:** HMAC-SHA1
- **Digits:** 6
- **Period:** 30 seconds
- **Window Tolerance:** ±1 period (±30 seconds)

### Security

- **Secret Storage:** 20-byte random secret in Keychain
- **Secret Generation:** `SecRandomCopyBytes` (cryptographically secure)
- **OTP Generation:** `otpauth://totp/Chronicle:username?secret=XXXXX`

---

## Network Security

### Current State

| Endpoint | Protocol | Security |
|----------|----------|----------|
| iCloud | HTTPS | Apple's TLS |
| Localhost API server | HTTP (localhost only) | No external exposure |
| External APIs | None | Chronicle does NOT call external APIs |

### TLS Configuration

For any future outbound HTTPS calls:
```swift
let config = URLSessionConfiguration.default
config.tlsMinimumSupportedProtocolVersion = .TLSv13
```

### Security Notes

- No analytics or telemetry
- No third-party SDKs that transmit data
- No outbound network calls except iCloud
- Localhost API server is **not** exposed externally

---

## Privacy Compliance

### Data Collection

| Category | Status |
|----------|--------|
| Personal data collected | **NONE** |
| Analytics/telemetry | **NONE** |
| Third-party SDKs | **NONE** |
| Network transmissions | iCloud only (user's own account) |

### PrivacyInfo.xcprivacy

All data practices are documented in `PrivacyInfo.xcprivacy` per Apple requirements.

### GDPR / CCPA

Chronicle supports data portability via the **Export All Data** feature:
- JSON export (full database dump)
- CSV export (bills + payments)
- PDF export (human-readable summary)
- ZIP bundle (all formats)

Export location: `~/Documents/Chronicle/Exports/[timestamp]/`

---

## Release Build Hardening

### Compiler Flags

```yaml
ENABLE_HARDENED_RUNTIME: YES
DEBUG_INFORMATION_FORMAT: dwarf-with-dsym  # Release only
SWIFT_OPTIMIZATION_LEVEL: -O  # Release
CODE_SIGN_IDENTITY: "-"  # Ad-hoc for development
```

### Stripping

Release builds have debug symbols stripped and archived in `.dSYM` files.

---

## Security Checklist

- [x] AES-256-GCM encryption for sensitive data
- [x] Encryption key stored in Keychain (not plain text)
- [x] Hardened Runtime enabled
- [x] App Sandbox enabled
- [x] Password lock with secure hashing
- [x] TOTP 2FA for API access
- [x] Privacy manifest (PrivacyInfo.xcprivacy)
- [x] No analytics or telemetry
- [x] No external network calls
- [x] Data export (GDPR portability)
- [x] Debugging disabled in Release builds
