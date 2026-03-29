import Foundation
import Security
import CryptoKit

/// R19: Password lock service for app privacy.
/// Stores a SHA-256 hash of the password in Keychain (never stores plain text).
final class PrivacyLockService {
    static let shared = PrivacyLockService()

    private let keychainService = "com.chronicle.privacy-lock"
    private let keychainAccount = "password-hash"
    private let keychainSaltAccount = "password-salt"

    private let enabledKey = "privacyLockEnabled"
    private let timeoutKey = "privacyLockTimeout"

    // Last activity timestamp (updated on app foreground)
    private var lastActivityTime: Date?

    private init() {
        // Set initial activity time
        lastActivityTime = Date()
    }

    // MARK: - Public API

    /// Whether the privacy lock is enabled.
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Lock timeout in seconds. Default is 300 (5 minutes).
    var lockTimeout: TimeInterval {
        get { UserDefaults.standard.double(forKey: timeoutKey).nonZeroOr(300) }
        set { UserDefaults.standard.set(newValue, forKey: timeoutKey) }
    }

    /// Enables privacy lock with the given password.
    /// - Throws: PrivacyLockError if password is too weak or Keychain fails.
    func enable(password: String) throws {
        guard password.count >= 6 else {
            throw PrivacyLockError.passwordTooWeak
        }

        let salt = generateSalt()
        let hash = hashPassword(password, salt: salt)

        // Store salt and hash in Keychain
        try saveToKeychain(data: salt, account: keychainSaltAccount)
        try saveToKeychain(data: hash, account: keychainAccount)

        UserDefaults.standard.set(true, forKey: enabledKey)
        recordActivity()
    }

    /// Disables privacy lock. Requires the current password for confirmation.
    func disable(password: String) throws {
        guard verifyPassword(password) else {
            throw PrivacyLockError.invalidPassword
        }

        deleteFromKeychain(account: keychainAccount)
        deleteFromKeychain(account: keychainSaltAccount)
        UserDefaults.standard.set(false, forKey: enabledKey)
    }

    /// Immediately locks the app.
    func lock() {
        recordActivity()
        NotificationCenter.default.post(name: .privacyLockDidEngage, object: nil)
    }

    /// Unlocks the app with the given password.
    /// Returns true if the password is correct.
    func unlock(password: String) -> Bool {
        let verified = verifyPassword(password)
        if verified {
            recordActivity()
            NotificationCenter.default.post(name: .privacyLockDidUnlock, object: nil)
        }
        return verified
    }

    /// Returns true if the app requires unlock based on timeout elapsed since last activity.
    func requiresUnlock() -> Bool {
        guard isEnabled else { return false }
        guard let lastActivity = lastActivityTime else { return true }
        return Date().timeIntervalSince(lastActivity) > lockTimeout
    }

    /// Records user activity (call when app becomes active or user interacts).
    func recordActivity() {
        lastActivityTime = Date()
    }

    /// Returns true if a password has been set (even if lock is disabled).
    var hasPasswordSet: Bool {
        loadFromKeychain(account: keychainAccount) != nil
    }

    // MARK: - Password Verification

    private func verifyPassword(_ password: String) -> Bool {
        guard let salt = loadFromKeychain(account: keychainSaltAccount),
              let storedHash = loadFromKeychain(account: keychainAccount) else {
            return false
        }

        let computedHash = hashPassword(password, salt: salt)
        return computedHash == storedHash
    }

    // MARK: - Key Derivation

    private func generateSalt() -> Data {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, 32, ptr.baseAddress!)
        }
        return salt
    }

    private func hashPassword(_ password: String, salt: Data) -> Data {
        let passwordData = Data(password.utf8)
        let combined = passwordData + salt

        // Use SHA-256 for password hashing
        let hash = SHA256.hash(data: combined)
        return Data(hash)
    }

    // MARK: - Keychain

    private func saveToKeychain(data: Data, account: String) throws {
        // Delete existing first
        deleteFromKeychain(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PrivacyLockError.keychainError("Failed to save: \(status)")
        }
    }

    private func loadFromKeychain(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
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

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum PrivacyLockError: Error, LocalizedError {
    case passwordTooWeak
    case invalidPassword
    case keychainError(String)

    var errorDescription: String? {
        switch self {
        case .passwordTooWeak:
            return "Password must be at least 6 characters."
        case .invalidPassword:
            return "Invalid password."
        case .keychainError(let msg):
            return "Keychain error: \(msg)"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let privacyLockDidEngage = Notification.Name("privacyLockDidEngage")
    static let privacyLockDidUnlock = Notification.Name("privacyLockDidUnlock")
}

// MARK: - Helpers

private extension Double {
    func nonZeroOr(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}
