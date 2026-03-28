import Foundation
import Security

// MARK: - API Key Service

/// Manages API key lifecycle: generation, Keychain storage, and validation.
final class APIKeyService {
    static let shared = APIKeyService()

    private let service = "com.chronicle.api"
    private let account = "api-key"

    private init() {}

    // MARK: - Public API

    /// Returns the stored API key, or nil if none exists.
    var storedKey: String? {
        getKeychainItem()
    }

    /// Generates a new 32-character lowercase-hex API key, stores it in Keychain, and returns it.
    @discardableResult
    func generateKey() -> String {
        let key = generateRandomHexKey()
        saveKeychainItem(key)
        return key
    }

    /// Validates the provided key against the Keychain-stored value.
    func validate(_ key: String) -> Bool {
        guard let stored = storedKey else { return false }
        return key == stored
    }

    /// Deletes the API key from Keychain.
    func deleteKey() {
        deleteKeychainItem()
    }

    /// Returns true if an API key exists in Keychain.
    var hasKey: Bool {
        storedKey != nil
    }

    // MARK: - Keychain Helpers

    private func generateRandomHexKey(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private func getKeychainItem() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private func saveKeychainItem(_ key: String) {
        deleteKeychainItem() // remove any existing item first

        guard let data = key.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteKeychainItem() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
