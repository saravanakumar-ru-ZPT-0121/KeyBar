import Foundation
import CryptoKit

/// HMAC algorithm used to generate a TOTP/HOTP code.
enum TOTPAlgorithm: String, Codable, CaseIterable, Identifiable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

/// Generates RFC 6238 Time-based One-Time Passwords (and the underlying RFC 4226
/// HOTP codes) using CryptoKit's HMAC primitives. No network access, no third
/// party crypto — everything here is implemented directly against the RFCs.
enum TOTPEngine {

    /// Generates the current TOTP code for the given secret and parameters.
    /// - Parameters:
    ///   - secret: The raw (already Base32-decoded) shared secret.
    ///   - algorithm: HMAC algorithm to use (default SHA1, as most services use).
    ///   - digits: Number of digits in the resulting code (typically 6 or 8).
    ///   - period: The time step in seconds (default 30, per RFC 6238).
    ///   - date: The reference time to generate the code for (defaults to now).
    static func generate(
        secret: Data,
        algorithm: TOTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        date: Date = Date()
    ) -> String {
        let counter = counterValue(for: date, period: period)
        return generate(secret: secret, algorithm: algorithm, digits: digits, counter: counter)
    }

    /// Generates an HOTP code (RFC 4226) for an explicit counter value. TOTP is
    /// simply HOTP with a time-derived counter, so this is the shared core.
    static func generate(
        secret: Data,
        algorithm: TOTPAlgorithm,
        digits: Int,
        counter: UInt64
    ) -> String {
        var counterBigEndian = counter.bigEndian
        let counterData = withUnsafeBytes(of: &counterBigEndian) { Data($0) }

        let hmacBytes = [UInt8](hmacDigest(key: secret, message: counterData, algorithm: algorithm))

        // Dynamic truncation, RFC 4226 section 5.3.
        let offset = Int(hmacBytes[hmacBytes.count - 1] & 0x0F)
        let truncatedBytes = hmacBytes[offset..<(offset + 4)]
        let truncatedValue = truncatedBytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let binaryCode = truncatedValue & 0x7FFF_FFFF

        let modulus = UInt32(pow(10.0, Double(digits)))
        let code = binaryCode % modulus

        return String(format: "%0\(digits)d", code)
    }

    /// Fraction of the current period elapsed, in the range [0, 1).
    static func progress(period: Int, date: Date = Date()) -> Double {
        let elapsed = date.timeIntervalSince1970.truncatingRemainder(dividingBy: Double(period))
        return elapsed / Double(period)
    }

    /// Seconds remaining until the next code, in the range (0, period].
    static func timeRemaining(period: Int, date: Date = Date()) -> TimeInterval {
        Double(period) - (date.timeIntervalSince1970.truncatingRemainder(dividingBy: Double(period)))
    }

    private static func counterValue(for date: Date, period: Int) -> UInt64 {
        UInt64(date.timeIntervalSince1970 / Double(period))
    }

    private static func hmacDigest(key: Data, message: Data, algorithm: TOTPAlgorithm) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        switch algorithm {
        case .sha1:
            return Data(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: symmetricKey))
        case .sha256:
            return Data(HMAC<SHA256>.authenticationCode(for: message, using: symmetricKey))
        case .sha512:
            return Data(HMAC<SHA512>.authenticationCode(for: message, using: symmetricKey))
        }
    }
}
