import Foundation

/// iCloud / CloudKit sync engine for Chronicle.
/// Uses NSUbiquitousKeyValueStore on Apple platforms and
/// a REST API wrapper for Android/web cross-platform sync.
public actor SyncEngine {
    private let store: ChronicleDataStore
    private let cloudContainer: CloudContainer

    public enum SyncState: Sendable {
        case idle
        case syncing
        case synced(Date)
        case error(String)
    }

    public private(set) var state: SyncState = .idle

    public init(store: ChronicleDataStore, cloudContainer: CloudContainer) {
        self.store = store
        self.cloudContainer = cloudContainer
    }

    /// Trigger a full sync with the cloud container.
    public func sync() async throws {
        state = .syncing
        do {
            // Pull remote changes
            let remoteBills = try await cloudContainer.fetchBills()
            let localBills = try await store.loadBills()

            // Merge: latest-wins based on updatedAt timestamp
            let merged = mergeBills(local: localBills, remote: remoteBills)
            try await store.saveBills(merged)

            // Push local changes back
            try await cloudContainer.pushBills(merged)

            state = .synced(Date())
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    private func mergeBills(local: [Bill], remote: [Bill]) -> [Bill] {
        var result: [UUID: Bill] = [:]

        for bill in local {
            result[bill.id] = bill
        }

        for remoteBill in remote {
            if let existing = result[remoteBill.id] {
                result[remoteBill.id] = (remoteBill.updatedAt > existing.updatedAt) ? remoteBill : existing
            } else {
                result[remoteBill.id] = remoteBill
            }
        }

        return Array(result.values)
    }
}

public enum CloudContainer: Sendable {
    case iCloud(containerIdentifier: String)
    case googleDrive(folderId: String)
    case localOnly
}
