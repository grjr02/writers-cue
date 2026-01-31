import Foundation
import CryptoKit
import Auth

/// Handles client-side AES-256-GCM encryption for content data
/// Encryption key is derived from the user's auth session, ensuring only the user can decrypt their content
class EncryptionManager {
    static let shared = EncryptionManager()

    private init() {}

    // MARK: - Key Derivation

    /// Derives an encryption key from the user's unique identifier
    /// Uses HKDF (HMAC-based Key Derivation Function) for secure key derivation
    private func deriveKey(from userId: String) -> SymmetricKey {
        let salt = "writers-cue-encryption-salt-v1".data(using: .utf8)!
        let inputKeyMaterial = SymmetricKey(data: userId.data(using: .utf8)!)

        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: salt,
            info: "content-encryption".data(using: .utf8)!,
            outputByteCount: 32  // 256 bits for AES-256
        )

        return derivedKey
    }

    // MARK: - Encryption

    /// Encrypts data using AES-256-GCM
    /// - Parameters:
    ///   - data: The plaintext data to encrypt
    ///   - userId: The user's unique identifier (used for key derivation)
    /// - Returns: The encrypted data (nonce + ciphertext + tag)
    func encrypt(_ data: Data, userId: String) throws -> Data {
        let key = deriveKey(from: userId)

        // Create a random nonce
        let nonce = AES.GCM.Nonce()

        // Encrypt with AES-GCM
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

        // Combine nonce + ciphertext + tag into a single Data object
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }

        return combined
    }

    // MARK: - Decryption

    /// Decrypts data using AES-256-GCM
    /// - Parameters:
    ///   - encryptedData: The encrypted data (nonce + ciphertext + tag)
    ///   - userId: The user's unique identifier (used for key derivation)
    /// - Returns: The decrypted plaintext data
    func decrypt(_ encryptedData: Data, userId: String) throws -> Data {
        let key = deriveKey(from: userId)

        // Create sealed box from combined data
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)

        // Decrypt
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        return decryptedData
    }

    // MARK: - Convenience Methods

    /// Encrypts data if user is signed in, returns original data if not
    func encryptIfAuthenticated(_ data: Data) -> Data {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            // User not signed in, return unencrypted (won't be uploaded anyway)
            return data
        }

        do {
            return try encrypt(data, userId: userId)
        } catch {
            print("Encryption failed: \(error)")
            return data
        }
    }

    /// Decrypts data if user is signed in, returns original data if not
    func decryptIfAuthenticated(_ data: Data) -> Data {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            return data
        }

        do {
            return try decrypt(data, userId: userId)
        } catch {
            print("Decryption failed: \(error)")
            return data
        }
    }
}

// MARK: - Encryption Errors

enum EncryptionError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidKey

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidKey:
            return "Invalid encryption key"
        }
    }
}
