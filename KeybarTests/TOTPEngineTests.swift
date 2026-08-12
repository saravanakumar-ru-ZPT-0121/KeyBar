import XCTest
@testable import Keybar

final class TOTPEngineTests: XCTestCase {

    // RFC 6238 Appendix B test vectors.
    private let seed20 = "12345678901234567890".data(using: .ascii)!
    private let seed32 = "12345678901234567890123456789012".data(using: .ascii)!
    private let seed64 = "1234567890123456789012345678901234567890123456789012345678901234".data(using: .ascii)!

    private struct Vector {
        let time: TimeInterval
        let sha1: String
        let sha256: String
        let sha512: String
    }

    private let vectors: [Vector] = [
        Vector(time: 59, sha1: "94287082", sha256: "46119246", sha512: "90693936"),
        Vector(time: 1_111_111_109, sha1: "07081804", sha256: "68084774", sha512: "25091201"),
        Vector(time: 1_111_111_111, sha1: "14050471", sha256: "67062674", sha512: "99943326"),
        Vector(time: 1_234_567_890, sha1: "89005924", sha256: "91819424", sha512: "93441116"),
        Vector(time: 2_000_000_000, sha1: "69279037", sha256: "90698825", sha512: "38618901"),
        Vector(time: 20_000_000_000, sha1: "65353130", sha256: "77737706", sha512: "47863826")
    ]

    func testRFC6238VectorsSHA1() {
        for vector in vectors {
            let date = Date(timeIntervalSince1970: vector.time)
            let code = TOTPEngine.generate(secret: seed20, algorithm: .sha1, digits: 8, period: 30, date: date)
            XCTAssertEqual(code, vector.sha1, "SHA1 mismatch at T=\(vector.time)")
        }
    }

    func testRFC6238VectorsSHA256() {
        for vector in vectors {
            let date = Date(timeIntervalSince1970: vector.time)
            let code = TOTPEngine.generate(secret: seed32, algorithm: .sha256, digits: 8, period: 30, date: date)
            XCTAssertEqual(code, vector.sha256, "SHA256 mismatch at T=\(vector.time)")
        }
    }

    func testRFC6238VectorsSHA512() {
        for vector in vectors {
            let date = Date(timeIntervalSince1970: vector.time)
            let code = TOTPEngine.generate(secret: seed64, algorithm: .sha512, digits: 8, period: 30, date: date)
            XCTAssertEqual(code, vector.sha512, "SHA512 mismatch at T=\(vector.time)")
        }
    }

    func testSixDigitCodeIsZeroPadded() {
        // Counter 0 with a trivial secret should still produce a full-width, zero-padded string.
        let secret = Data([0x00])
        let code = TOTPEngine.generate(secret: secret, algorithm: .sha1, digits: 6, counter: 0)
        XCTAssertEqual(code.count, 6)
    }

    func testTimeRemainingDecreasesWithinPeriod() {
        let date = Date(timeIntervalSince1970: 1000) // 1000 % 30 = 10s elapsed -> 20s remaining
        let remaining = TOTPEngine.timeRemaining(period: 30, date: date)
        XCTAssertEqual(remaining, 20, accuracy: 0.001)
    }

    func testProgressWithinPeriod() {
        let date = Date(timeIntervalSince1970: 1000) // 10s elapsed of a 30s period
        let progress = TOTPEngine.progress(period: 30, date: date)
        XCTAssertEqual(progress, 10.0 / 30.0, accuracy: 0.001)
    }
}
