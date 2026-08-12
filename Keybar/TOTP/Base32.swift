import Foundation

/// RFC 4648 Base32 encoding/decoding, used for TOTP shared secrets.
enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    private static let charMap: [Character: UInt8] = {
        var map = [Character: UInt8]()
        for (index, char) in alphabet.enumerated() {
            map[char] = UInt8(index)
        }
        return map
    }()

    /// Decodes an RFC 4648 Base32 string (case-insensitive, tolerant of padding
    /// and whitespace) into raw bytes. Returns `nil` if the string contains
    /// characters outside the Base32 alphabet.
    static func decode(_ input: String) -> Data? {
        let cleaned = input
            .uppercased()
            .replacingOccurrences(of: "=", with: "")
            .filter { !$0.isWhitespace }

        guard !cleaned.isEmpty else { return nil }

        var bits = 0
        var value: UInt32 = 0
        var output = [UInt8]()
        output.reserveCapacity(cleaned.count * 5 / 8)

        for char in cleaned {
            guard let charValue = charMap[char] else { return nil }
            value = (value << 5) | UInt32(charValue)
            bits += 5
            if bits >= 8 {
                bits -= 8
                output.append(UInt8((value >> UInt32(bits)) & 0xFF))
            }
        }

        return Data(output)
    }

    /// Encodes raw bytes into an RFC 4648 Base32 string without padding.
    static func encode(_ data: Data) -> String {
        var bits = 0
        var value: UInt32 = 0
        var output = ""
        output.reserveCapacity((data.count * 8 + 4) / 5)

        for byte in data {
            value = (value << 8) | UInt32(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                output.append(alphabet[Int((value >> UInt32(bits)) & 0x1F)])
            }
        }

        if bits > 0 {
            output.append(alphabet[Int((value << UInt32(5 - bits)) & 0x1F)])
        }

        return output
    }
}
