import Foundation

/// Non-secret metadata describing a TOTP account. The shared secret itself is
/// never stored here — it lives exclusively in the Keychain, keyed by `id`.
struct Account: Identifiable, Codable, Equatable {
    let id: UUID
    var issuer: String
    var accountName: String
    var algorithm: TOTPAlgorithm
    var digits: Int
    var period: Int
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        issuer: String,
        accountName: String,
        algorithm: TOTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.issuer = issuer
        self.accountName = accountName
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.sortOrder = sortOrder
    }

    /// A display label combining issuer and account name, e.g. "GitHub".
    var displayLabel: String {
        issuer.isEmpty ? accountName : issuer
    }

    /// Masks the account name for display, e.g. "ja••••om".
    var maskedAccountName: String {
        Account.mask(accountName)
    }

    static func mask(_ value: String) -> String {
        guard value.count > 4 else {
            return String(repeating: "•", count: max(value.count, 3))
        }
        let prefix = value.prefix(2)
        let suffix = value.suffix(2)
        return "\(prefix)••••\(suffix)"
    }
}
