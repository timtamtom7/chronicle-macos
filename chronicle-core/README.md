# ChronicleCore

> Core data layer and sync engine for Chronicle — MIT open source.

ChronicleCore contains the shared domain models, data store interface, iCloud sync
engine, and encryption utilities used across all Chronicle clients.

The UI layer and any proprietary features (notifications, widgets, shortcuts, analytics)
are **not** included here and remain closed source.

## What's Included

| File | Purpose |
|------|---------|
| `Models.swift` | `Bill`, `BillCategory`, `MonthlySpending` — shared Codable structs |
| `DataStore.swift` | `ChronicleDataStore` protocol + `ChronicleSettings` |
| `SyncEngine.swift` | iCloud / Google Drive sync with conflict resolution |
| `Encryption.swift` | AES-GCM encryption at rest + PBKDF2 key derivation |

## Supported Platforms

- **macOS 13+**
- **iOS 16+**
- **tvOS 16+**
- **watchOS 9+**

(Would need a separate Android/web port of the Swift package to be usable there,
or the models could be extracted as a separate language-agnostic schema.)

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/chronicle/chronicle-core", from: "1.0.0")
```

### Xcode

File → Add Packages → `https://github.com/chronicle/chronicle-core`

## Usage

```swift
import ChronicleCore

// Use shared models
let bill = Bill(name: "Electricity", amount: 120, dueDay: 15, category: .utilities)

// Implement ChronicleDataStore for your platform
struct MyDataStore: ChronicleDataStore {
    func loadBills() async throws -> [Bill] { ... }
    func saveBills(_ bills: [Bill]) async throws { ... }
    func loadSpendingHistory() async throws -> [MonthlySpending] { ... }
    func saveSpendingHistory(_ history: [MonthlySpending]) async throws { ... }
    func loadSettings() async throws -> ChronicleSettings { ... }
    func saveSettings(_ settings: ChronicleSettings) async throws { ... }
}

// Sync with iCloud
let engine = SyncEngine(store: MyDataStore(), cloudContainer: .iCloud(containerIdentifier: "iCloud.com.chronicle.app"))
try await engine.sync()
```

## Contributing

Contributions are welcome! Please open an issue or PR.

- Bug fixes: direct PRs welcome
- New platform ports: please open an issue first to discuss
- Sync backends: PRs for additional cloud providers (Dropbox, OneDrive) would be considered

## License

MIT — see `LICENSE`.
