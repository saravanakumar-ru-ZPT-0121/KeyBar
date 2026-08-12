import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case dataConversionFailed

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown error"
            return "Keychain operation failed (\(status)): \(message)"
        case .dataConversionFailed:
            return "Failed to read Keychain data."
        }
    }
}

/// Stores and retrieves TOTP secrets in the macOS Keychain as generic passwords
/// (`kSecClassGenericPassword`), keyed by the account's UUID. This is the only
/// place in the app that ever touches raw secret bytes.
struct KeychainStore {
    private let service = "com.keybar.totp.secrets"

    private func baseQuery(account: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.uuidString
        ]
    }

    /// Saves (or overwrites) the secret for a given account UUID.
    func saveSecret(_ secret: Data, for account: UUID) throws {
        if try secretExists(for: account) {
            let query = baseQuery(account: account)
            let attributesToUpdate: [String: Any] = [kSecValueData as String: secret]
            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        } else {
            var query = baseQuery(account: account)
            query[kSecValueData as String] = secret
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        }
    }

    /// Loads the raw secret bytes for a given account UUID.
    func loadSecret(for account: UUID) throws -> Data {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = result as? Data else { throw KeychainError.dataConversionFailed }
        return data
    }

    /// Deletes the stored secret for a given account UUID, if any.
    func deleteSecret(for account: UUID) throws {
        let query = baseQuery(account: account)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func secretExists(for account: UUID) throws -> Bool {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = false
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess: return true
        case errSecItemNotFound: return false
        default: throw KeychainError.unexpectedStatus(status)
        }
    }
}
