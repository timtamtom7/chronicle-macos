import Foundation
import Security
import CryptoKit

/// R19: AES-256-GCM encryption service using CryptoKit.
/// Encryption key is stored in the macOS Keychain and never in plain text.
final class EncryptionService {
    static let shared = EncryptionService()

    private let keychainService = "com.chronicle.encryption"
    private let keychainAccount = "aes256-key"

    private var symmetricKey: SymmetricKey?

    private init() {}

    // MARK: - Public API

    /// Initializes (or generates) the AES-256 encryption key.
    /// Call this on app launch BEFORE any database operations.
    func initializeKey() throws {
        if let keyData = loadKeyFromKeychain() {
            symmetricKey = SymmetricKey(data: keyData)
        } else {
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            try saveKeyToKeychain(keyData)
            symmetricKey = key
        }
    }

    /// Encrypts data using AES-256-GCM. Returns combined ciphertext (nonce + ciphertext + tag).
    func encrypt(_ data: Data) throws -> Data {
        guard let key = symmetricKey else {
            throw EncryptionError.keyNotInitialized
        }
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }
            return combined
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }

    /// Decrypts AES-256-GCM combined ciphertext.
    func decrypt(_ data: Data) throws -> Data {
        guard let key = symmetricKey else {
            throw EncryptionError.keyNotInitialized
        }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    /// Encrypts a string and returns base64-encoded ciphertext.
    func encryptString(_ string: String) throws -> String {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.encryptionFailed
        }
        let encrypted = try encrypt(data)
        return encrypted.base64EncodedString()
    }

    /// Decrypts a base64-encoded ciphertext and returns the original string.
    func decryptString(_ base64String: String) throws -> String {
        guard let data = Data(base64Encoded: base64String) else {
            throw EncryptionError.decryptionFailed
        }
        let decrypted = try decrypt(data)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        return string
    }

    // MARK: - Keychain Storage

    private func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }

    private func saveKeyToKeychain(_ keyData: Data) throws {
        // Delete existing key first
        deleteKeyFromKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keychainError("Failed to save key: \(status)")
        }
    }

    private func deleteKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum EncryptionError: Error, LocalizedError {
    case keyNotInitialized
    case encryptionFailed
    case decryptionFailed
    case keychainError(String)

    var errorDescription: String? {
        switch self {
        case .keyNotInitialized:
            return "Encryption key not initialized. Call initializeKey() first."
        case .encryptionFailed:
            return "Encryption failed."
        case .decryptionFailed:
            return "Decryption failed. Data may be corrupted or the key is wrong."
        case .keychainError(let msg):
            return "Keychain error: \(msg)"
        }
    }
}
