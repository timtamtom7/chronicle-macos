import Foundation
import Security
import CryptoKit
import CoreImage.CIFilterBuiltins

/// R19: TOTP (Time-based One-Time Password) service for 2FA on API access.
/// Implements RFC 6238 TOTP with SHA-1, 6 digits, 30-second window.
final class TOTPService {
    static let shared = TOTPService()

    private let keychainService = "com.chronicle.totp"
    private let keychainAccount = "totp-secret"

    private let enabledKey = "totpEnabled"
    private let usernameKey = "totpUsername"

    /// TOTP parameters per RFC 6238
    private let digits = 6
    private let period: TimeInterval = 30
    private let algorithm = HMAC<Insecure.SHA1>.self // Standard TOTP uses SHA-1

    private var cachedSecret: Data?

    private init() {}

    // MARK: - Public API

    /// Whether TOTP 2FA is enabled for API access.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Username associated with the TOTP account.
    var username: String? {
        get { UserDefaults.standard.string(forKey: usernameKey) }
        set { UserDefaults.standard.set(newValue, forKey: usernameKey) }
    }

    /// Generates a new random TOTP secret (20 bytes / 160 bits of entropy).
    /// Stores it in Keychain and returns the base32-encoded secret.
    func generateSecret() -> String {
        let secret = generateRandomSecret()
        saveSecretToKeychain(secret)
        return secret.base32EncodedString()
    }

    /// Sets up TOTP with an existing base32-encoded secret.
    func setupTOTP(username: String, secret: String) throws {
        guard let secretData = base32Decode(secret) else {
            throw TOTPError.invalidSecret
        }
        saveSecretToKeychain(secretData)
        self.username = username
        self.isEnabled = true
    }

    /// Generates the current TOTP code (6 digits).
    func generateCode() -> String? {
        guard let secret = loadSecretFromKeychain() else { return nil }
        return generateTOTP(secret: secret, counter: currentCounter())
    }

    /// Verifies a TOTP code with ±1 window tolerance (30 seconds before/after).
    func verifyCode(_ code: String) -> Bool {
        guard let secret = loadSecretFromKeychain() else { return false }
        guard code.count == digits, code.allSatisfy({ $0.isNumber }) else { return false }

        let counter = currentCounter()

        // Check current, previous, and next counter values
        for offset in -1...1 {
            let candidate = generateTOTP(secret: secret, counter: counter + UInt64(truncatingIfNeeded: offset))
            if code == candidate {
                return true
            }
        }
        return false
    }

    /// Generates the otpauth:// URI for QR code setup.
    /// Example: otpauth://totp/Chronicle:user@example.com?secret=XXXXXXXX&issuer=Chronicle
    func generateAuthURI() -> String? {
        guard let secret = loadSecretFromKeychain(),
              let user = username else {
            return nil
        }
        let encodedSecret = secret.base32EncodedString()
        let issuer = "Chronicle"
        let label = "\(issuer):\(user)"
        return "otpauth://totp/\(label)?secret=\(encodedSecret)&issuer=\(issuer)&algorithm=SHA1&digits=\(digits)&period=\(Int(period))"
    }

    /// Generates a QR code image (CGImage) for the TOTP setup URI.
    func generateQRCode() -> CGImage? {
        guard let uri = generateAuthURI(),
              let data = uri.data(using: .utf8) else {
            return nil
        }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        return context.createCGImage(scaledImage, from: scaledImage.extent)
    }

    /// Disables TOTP 2FA.
    func disable() {
        deleteSecretFromKeychain()
        isEnabled = false
        username = nil
        cachedSecret = nil
    }

    // MARK: - TOTP Generation

    private func currentCounter() -> UInt64 {
        let now = Date().timeIntervalSince1970
        return UInt64(now / period)
    }

    private func generateTOTP(secret: Data, counter: UInt64) -> String {
        // Convert counter to 8-byte big-endian
        var counterBE = counter.bigEndian
        let counterData = Data(bytes: &counterBE, count: 8)

        // Compute HMAC
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: SymmetricKey(data: secret))
        let hmacData = Data(hmac)

        // Dynamic truncation
        let offset = Int(hmacData[hmacData.count - 1] & 0x0F)
        let truncatedHash = hmacData[offset..<offset+4]

        var code: UInt32 = 0
        truncatedHash.withUnsafeBytes { ptr in
            code = ptr.load(as: UInt32.self).bigEndian
        }
        code &= 0x7FFFFFFF

        let otp = code % UInt32(pow(10, Double(digits)))
        return String(format: "%0\(digits)d", otp)
    }

    // MARK: - Keychain Storage

    private func generateRandomSecret() -> Data {
        var secret = Data(count: 20)
        _ = secret.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, 20, ptr.baseAddress!)
        }
        return secret
    }

    private func saveSecretToKeychain(_ secret: Data) {
        deleteSecretFromKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: secret,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemAdd(query as CFDictionary, nil)
        cachedSecret = secret
    }

    private func loadSecretFromKeychain() -> Data? {
        if let cached = cachedSecret {
            return cached
        }

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
        cachedSecret = data
        return data
    }

    private func deleteSecretFromKeychain() {
        cachedSecret = nil
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Base32

extension Data {
    /// Base32 encodes the data using the standard alphabet (RFC 4648).
    func base32EncodedString() -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var bits = 0
        var value = 0
        var output = ""

        for byte in self {
            value = (value << 8) | Int(byte)
            bits += 8

            while bits >= 5 {
                let index = (value >> (bits - 5)) & 31
                output.append(alphabet[index])
                bits -= 5
            }
        }

        if bits > 0 {
            let index = (value << (5 - bits)) & 31
            output.append(alphabet[index])
        }

        return output
    }
}

/// Decodes a base32 string (RFC 4648) to Data. Returns nil on invalid input.
private func base32Decode(_ string: String) -> Data? {
    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    let uppercased = string.uppercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "=", with: "")

    var bits = 0
    var value = 0
    var output = Data()

    for char in uppercased {
        guard let index = alphabet.firstIndex(of: char) else {
            // Skip padding characters, reject others
            if char == "=" { continue }
            return nil
        }
        let n = alphabet.distance(from: alphabet.startIndex, to: index)
        value = (value << 5) | n
        bits += 5

        if bits >= 8 {
            let byte = UInt8((value >> (bits - 8)) & 0xFF)
            output.append(byte)
            bits -= 8
        }
    }

    return output.isEmpty ? nil : output
}

// MARK: - Errors

enum TOTPError: Error, LocalizedError {
    case invalidSecret
    case notSetup

    var errorDescription: String? {
        switch self {
        case .invalidSecret:
            return "Invalid TOTP secret. Must be a valid base32 string."
        case .notSetup:
            return "TOTP is not set up."
        }
    }
}
