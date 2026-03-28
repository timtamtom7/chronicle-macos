import Foundation
import CloudKit
import Security
import CryptoKit

final class iCloudSyncManager: ObservableObject {
    static let shared = iCloudSyncManager()

    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSynced: Date?
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "iCloudSyncEnabled")
            if isEnabled {
                startSync()
            }
        }
    }

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced
        case error(String)
    }

    private let containerIdentifier = "iCloud.com.chronicle.macos"
    private lazy var container = CKContainer(identifier: containerIdentifier)
    private lazy var privateDatabase = container.privateCloudDatabase

    private let encryptedBillsZoneID = CKRecordZone.ID(zoneName: "EncryptedBills", ownerName: CKCurrentUserDefaultName)
    private var encryptionKey: Data?

    private let syncQueue = DispatchQueue(label: "com.chronicle.sync", qos: .utility)
    private var pendingSyncWorkItem: DispatchWorkItem?

    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? false
        loadEncryptionKey()
        setupNotifications()
    }

    // MARK: - Encryption

    func generateEncryptionKey() -> Data? {
        var keyBytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, 32, &keyBytes)
        guard status == errSecSuccess else { return nil }
        return Data(keyBytes)
    }

    func loadEncryptionKey() {
        if let existingKey = loadKeyFromKeychain() {
            encryptionKey = existingKey
            return
        }

        if let newKey = generateEncryptionKey() {
            saveKeyToKeychain(newKey)
            encryptionKey = newKey
        }
    }

    private func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.chronicle.encryption",
            kSecAttrAccount as String: "chronicle-sync-key",
            kSecReturnData as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    private func saveKeyToKeychain(_ key: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.chronicle.encryption",
            kSecAttrAccount as String: "chronicle-sync-key",
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func exportEncryptionKeyBase64() -> String? {
        encryptionKey?.base64EncodedString()
    }

    func importEncryptionKeyBase64(_ base64: String) -> Bool {
        guard let keyData = Data(base64Encoded: base64), keyData.count == 32 else { return false }
        saveKeyToKeychain(keyData)
        encryptionKey = keyData
        return true
    }

    // MARK: - AES-256-GCM Encryption

    private func encrypt(_ data: Data) -> Data? {
        guard let key = encryptionKey else { return nil }

        var nonceBytes = [UInt8](repeating: 0, count: 12)
        _ = SecRandomCopyBytes(kSecRandomDefault, 12, &nonceBytes)
        let nonce = Data(nonceBytes)

        let keySym = SymmetricKey(data: key)
        guard let sealed = try? AES.GCM.seal(data, using: keySym, nonce: AES.GCM.Nonce(data: nonce)) else {
            return nil
        }

        var result = Data()
        result.append(nonce)
        result.append(sealed.combined!)
        return result
    }

    private func decrypt(_ data: Data) -> Data? {
        guard let key = encryptionKey, data.count > 12 else { return nil }

        let nonce = data.prefix(12)
        let ciphertext = data.dropFirst(12)

        let keySym = SymmetricKey(data: key)
        guard let nonceObj = try? AES.GCM.Nonce(data: nonce),
              let sealed = try? AES.GCM.SealedBox(combined: ciphertext),
              let decrypted = try? AES.GCM.open(sealed, using: keySym) else {
            return nil
        }
        return decrypted
    }

    // MARK: - CloudKit Zone Setup

    func setupZone() async throws {
        let zone = CKRecordZone(zoneID: encryptedBillsZoneID)
        _ = try await privateDatabase.save(zone)
    }

    private func ensureZoneExists() async throws {
        do {
            _ = try await privateDatabase.recordZone(for: encryptedBillsZoneID)
        } catch {
            try await setupZone()
        }
    }

    // MARK: - Sync

    func startSync() {
        guard isEnabled else { return }
        syncStatus = .syncing

        Task {
            do {
                try await ensureZoneExists()
                try await uploadLocalData()
                try await downloadRemoteData()
                await MainActor.run {
                    self.syncStatus = .synced
                    self.lastSynced = Date()
                    UserDefaults.standard.set(Date(), forKey: "lastSyncTime")
                }
            } catch {
                await MainActor.run {
                    self.syncStatus = .error(error.localizedDescription)
                }
            }
        }
    }

    func forceSyncNow() {
        pendingSyncWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.startSync()
        }
        pendingSyncWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    func uploadLocalData() async throws {
        guard let key = encryptionKey else { throw SyncError.noEncryptionKey }

        let bills = try DatabaseService.shared.fetchAllBills()
        let payments = try DatabaseService.shared.fetchAllPaymentRecords()

        let exportData = SyncExportData(bills: bills, payments: payments, exportedAt: Date())
        let jsonData = try JSONEncoder().encode(exportData)

        guard let encrypted = encrypt(jsonData) else { throw SyncError.encryptionFailed }

        let recordID = CKRecord.ID(recordName: "chronicle-sync-data", zoneID: encryptedBillsZoneID)
        let record = CKRecord(recordType: "EncryptedPayload", recordID: recordID)
        record["encrypted_payload"] = encrypted as CKRecordValue
        record["updated_at"] = Date() as CKRecordValue
        record["entity_type"] = "sync" as CKRecordValue

        _ = try await privateDatabase.save(record)
    }

    func downloadRemoteData() async throws {
        let query = CKQuery(recordType: "EncryptedPayload", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "updated_at", ascending: false)]

        let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: encryptedBillsZoneID)

        guard let latestRecord = results.first?.1,
              case .success(let record) = latestRecord,
              let encrypted = record["encrypted_payload"] as? Data,
              let decrypted = decrypt(encrypted),
              let syncData = try? JSONDecoder().decode(SyncExportData.self, from: decrypted) else {
            return
        }

        await mergeData(syncData)
    }

    private func mergeData(_ syncData: SyncExportData) async {
        for var bill in syncData.bills {
            if let existing = try? DatabaseService.shared.fetchBill(by: bill.id) {
                if bill.createdAt > existing.createdAt {
                    try? DatabaseService.shared.updateBill(bill)
                }
            } else {
                try? DatabaseService.shared.insertBill(bill)
            }
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSNotification.Name("NSUbiquitousKeyValueStoreDidChangeExternally"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange),
            name: NSNotification.Name("ChronicleDataDidChange"),
            object: nil
        )

        // Household iCloud sync notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(householdStoreDidChange),
            name: NSNotification.Name("NSUbiquitousKeyValueStoreDidChangeExternally"),
            object: Self.householdStore
        )
    }

    @objc private func householdStoreDidChange(_ notification: Notification) {
        if isEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.handleHouseholdCloudChange(notification)
            }
        }
    }

    @objc private func storeDidChange(_ notification: Notification) {
        if isEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.startSync()
            }
        }
    }

    @objc private func handleDataChange() {
        pendingSyncWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                self?.startSync()
            }
        }
        pendingSyncWorkItem = workItem
        DispatchQueue.global().async(execute: workItem)
    }
}

// MARK: - Supporting Types

struct SyncExportData: Codable {
    let bills: [Bill]
    let payments: [PaymentRecord]
    let exportedAt: Date
    let appVersion: String = "R5"

    enum CodingKeys: String, CodingKey {
        case bills, payments, exportedAt, appVersion
    }
}

enum SyncError: Error {
    case noEncryptionKey
    case encryptionFailed
    case decryptionFailed
    case networkError
}

// MARK: - Household iCloud Sync

extension iCloudSyncManager {
    private static let householdStore = NSUbiquitousKeyValueStore.default
    private static let householdMetadataKey = "household_metadata"
    private static let householdSharedBillsKey = "household_shared_bills"
    private static let appGroupID = "group.com.chronicle.macos.household"

    /// Syncs household metadata to iCloud via NSUbiquitousKeyValueStore
    func syncHouseholdToCloud(_ household: Household) {
        guard isEnabled else { return }

        Task { @MainActor in
            HouseholdService.shared.syncStatus = .syncing
        }

        if let data = try? JSONEncoder().encode(HouseholdCloudPayload(
            id: household.id,
            name: household.name,
            members: household.members.map { MemberPayload(id: $0.id, name: $0.name, avatarName: $0.avatarName, colorHex: $0.colorHex, colorHexDark: $0.colorHexDark, role: $0.role.rawValue) },
            inviteCode: household.inviteCode,
            sharedBillIds: household.bills,
            updatedAt: Date()
        )) {
            Self.householdStore.set(data, forKey: Self.householdMetadataKey)
            Self.householdStore.set(household.bills.map { $0.uuidString }, forKey: Self.householdSharedBillsKey)
            Self.householdStore.synchronize()

            Task { @MainActor in
                HouseholdService.shared.syncStatus = .idle
            }
        } else {
            Task { @MainActor in
                HouseholdService.shared.syncStatus = .error("Failed to encode household data")
            }
        }
    }

    /// Loads household metadata from iCloud
    func loadHouseholdFromCloud() -> HouseholdCloudPayload? {
        guard isEnabled,
              let data = Self.householdStore.data(forKey: Self.householdMetadataKey),
              let payload = try? JSONDecoder().decode(HouseholdCloudPayload.self, from: data) else {
            return nil
        }
        return payload
    }

    /// Stores shared bill IDs in the App Group suite for cross-device access
    func syncSharedBillIdsToAppGroup(_ billIds: [UUID]) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        defaults.set(billIds.map { $0.uuidString }, forKey: Self.householdSharedBillsKey)
    }

    /// Loads shared bill IDs from App Group suite
    func loadSharedBillIdsFromAppGroup() -> Set<UUID> {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let strings = defaults.stringArray(forKey: Self.householdSharedBillsKey) else {
            return []
        }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    /// Handles external iCloud changes to household data
    @objc func handleHouseholdCloudChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        switch changeReason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            // Remote household data changed — reload
            Task { @MainActor in
                HouseholdService.shared.syncStatus = .idle
            }
            if let payload = loadHouseholdFromCloud() {
                NotificationCenter.default.post(
                    name: .householdDidChange,
                    object: nil,
                    userInfo: ["payload": payload]
                )
            }
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            Task { @MainActor in
                HouseholdService.shared.syncStatus = .error("iCloud quota exceeded")
            }
            print("Household sync quota exceeded")
        case NSUbiquitousKeyValueStoreAccountChange:
            // iCloud account changed — re-authenticate
            Task { @MainActor in
                HouseholdService.shared.syncStatus = .idle
            }
            NotificationCenter.default.post(name: .householdDidChange, object: nil)
        default:
            break
        }
    }
}

// MARK: - Cloud Payload Types

struct HouseholdCloudPayload: Codable {
    let id: UUID
    let name: String
    let members: [MemberPayload]
    let inviteCode: String
    let sharedBillIds: [UUID]
    let updatedAt: Date
}

struct MemberPayload: Codable {
    let id: UUID
    let name: String
    let avatarName: String
    let colorHex: String
    let colorHexDark: String?
    let role: String
}
