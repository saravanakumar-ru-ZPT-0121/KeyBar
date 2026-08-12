import XCTest
@testable import Keybar

final class Base32Tests: XCTestCase {

    func testDecodeKnownVector() {
        // Base32 of "12345678901234567890" (the RFC 6238 SHA1 seed).
        let decoded = Base32.decode("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ")
        XCTAssertEqual(decoded, "12345678901234567890".data(using: .ascii)!)
    }

    func testDecodeIsCaseInsensitiveAndIgnoresPaddingAndWhitespace() {
        let upper = Base32.decode("JBSWY3DPEHPK3PXP")
        let messy = Base32.decode("jbsw y3dp ehpk 3pxp ====")
        XCTAssertNotNil(upper)
        XCTAssertEqual(upper, messy)
    }

    func testDecodeRejectsInvalidCharacters() {
        XCTAssertNil(Base32.decode("this is not base32!!!"))
    }

    func testEncodeDecodeRoundTrip() {
        let original = Data((0..<37).map { UInt8(($0 * 7) % 256) })
        let encoded = Base32.encode(original)
        let decoded = Base32.decode(encoded)
        XCTAssertEqual(decoded, original)
    }
}
