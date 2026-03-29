import Foundation
import CryptoKit

/// Encryption utilities for Chronicle.
/// Bills and settings are encrypted at rest using AES-GCM.
/// Key derivation uses PBKDF2 with a per-device salt.
public enum Encryption {
    public enum EncryptionError: Error, Sendable {
        case keyDerivationFailed
        case encryptionFailed
        case decryptionFailed
        case invalidData
    }

    /// Derive a symmetric key from a user-provided passphrase using PBKDF2.
    public static func deriveKey(passphrase: String, salt: Data) throws -> SymmetricKey {
        // PBKDF2 with SHA256, 100_000 iterations
        guard let passphraseData = passphrase.data(using: .utf8) else {
            throw EncryptionError.keyDerivationFailed
        }

        let key = try SymmetricKey(
            _rawKeyData: pbkdf2SHA256(
                password: passphraseData,
                salt: salt,
                iterations: 100_000,
                keyLength: 32
            )
        )
        return key
    }

    /// Encrypt data using AES-GCM with a random nonce.
    public static func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
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

    /// Decrypt data using AES-GCM.
    public static func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    /// Generate a random salt for key derivation.
    public static func generateSalt(length: Int = 32) -> Data {
        var data = Data(count: length)
        _ = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, length, bytes.baseAddress!)
        }
        return data
    }

    // MARK: - Private PBKDF2 implementation

    private static func pbkdf2SHA256(
        password: Data,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) throws -> Data {
        var derivedKey = Data(count: keyLength)
        var salt = salt

        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeMutableBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard result == kCCSuccess else {
            throw EncryptionError.keyDerivationFailed
        }

        return derivedKey
    }
}

// CommonCrypto import for PBKDF2
import CommonCrypto
