import Foundation
import CryptoKit

/// R19: Privacy and Security Service
/// AES-256 encryption, Keychain integration, privacy manifest
public final class PrivacyService {
    
    public static let shared = PrivacyService()
    
    private let keychainService = "com.chronicle.macos.encryption"
    private let keychainAccount = "database-encryption-key"
    
    private init() {}
    
    // MARK: - Encryption Key Management
    
    /// Generates or retrieves the database encryption key from Keychain
    public func getOrCreateEncryptionKey() throws -> SymmetricKey {
        // Try to retrieve existing key
        if let existingKey = try? retrieveKeyFromKeychain() {
            return existingKey
        }
        
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        try storeKeyInKeychain(newKey)
        return newKey
    }
    
    /// Encrypts data using AES-256-GCM
    public func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        guard let combined = sealedBox.combined else {
            throw PrivacyError.encryptionFailed
        }
        
        return combined
    }
    
    /// Decrypts AES-256-GCM encrypted data
    public func decrypt(_ encryptedData: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - String Encryption
    
    public func encryptString(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw PrivacyError.encodingFailed
        }
        return try encrypt(data)
    }
    
    public func decryptString(_ encryptedData: Data) throws -> String {
        let decrypted = try decrypt(encryptedData)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw PrivacyError.decodingFailed
        }
        return string
    }
    
    // MARK: - Keychain Operations
    
    private func storeKeyInKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw PrivacyError.keychainStoreFailed(status)
        }
    }
    
    private func retrieveKeyFromKeychain() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            throw PrivacyError.keychainRetrieveFailed(status)
        }
        
        return SymmetricKey(data: keyData)
    }
    
    // MARK: - Data Export & Deletion (R19)
    
    /// Exports all user data as JSON - MUST be called from MainActor context
    @MainActor
    public func exportAllData() throws -> Data {
        let billStore = BillStore.shared
        billStore.loadBills()
        
        let exportData: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "version": "1.0",
            "bills": billStore.bills.map { bill -> [String: Any] in
                [
                    "id": bill.id.uuidString,
                    "name": bill.name,
                    "amount": "\(bill.amount)",
                    "dueDate": ISO8601DateFormatter().string(from: bill.dueDate),
                    "category": bill.category.rawValue,
                    "isPaid": bill.isPaid,
                    "dueDay": bill.dueDay
                ]
            }
        ]
        
        return try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
    }
    
    /// Exports data as CSV - MUST be called from MainActor context
    @MainActor
    public func exportAllDataAsCSV() -> String {
        let billStore = BillStore.shared
        billStore.loadBills()
        
        var csv = "ID,Name,Amount,Due Date,Category,Is Paid,Due Day\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        for bill in billStore.bills {
            let row = [
                bill.id.uuidString,
                "\"\(bill.name)\"",
                "\(bill.amount)",
                dateFormatter.string(from: bill.dueDate),
                "\"\(bill.category.rawValue)\"",
                bill.isPaid ? "Yes" : "No",
                "\(bill.dueDay)"
            ].joined(separator: ",")
            csv += row + "\n"
        }
        
        return csv
    }
    
    /// Wipes all local data - MUST be called from MainActor context
    @MainActor
    public func wipeAllData() {
        let billStore = BillStore.shared
        billStore.loadBills()
        
        // Delete all bills
        for bill in billStore.bills {
            billStore.deleteBill(bill.id)
        }
        
        // Clear UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
        
        // Clear Keychain
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService
        ]
        SecItemDelete(keychainQuery as CFDictionary)
    }
    
    // MARK: - Privacy Manifest
    
    /// Returns privacy manifest data for App Store submission
    public static var privacyManifest: [String: Any] {
        [
            "NSPrivacyTracking": false,
            "NSPrivacyTrackingDomains": [],
            "NSPrivacyCollectedDataTypes": [],
            "NSPrivacyAccessedDataTypes": [
                [
                    "NSPrivacyAccessedDataType": "NSPrivacyAccessedDataTypeUserDefaults",
                    "NSPrivacyAccessedDataTypeReasons": ["CA92.1"]
                ]
            ]
        ]
    }
}

// MARK: - Errors

public enum PrivacyError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case encodingFailed
    case decodingFailed
    case keychainStoreFailed(OSStatus)
    case keychainRetrieveFailed(OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "Failed to encrypt data"
        case .decryptionFailed: return "Failed to decrypt data"
        case .encodingFailed: return "Failed to encode string"
        case .decodingFailed: return "Failed to decode string"
        case .keychainStoreFailed(let s): return "Keychain store failed: \(s)"
        case .keychainRetrieveFailed(let s): return "Keychain retrieve failed: \(s)"
        }
    }
}
