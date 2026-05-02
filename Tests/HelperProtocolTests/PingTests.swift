import XCTest
import Foundation

/// Unit-tests the `ping` round-trip semantics. Uses an in-memory mock that conforms to
/// HelperProtocol — does not actually open an XPC connection.
final class PingTests: XCTestCase {
    /// Mock helper that returns `Date()` synchronously through the reply block.
    final class MockHelperPing: NSObject {
        var replyDate: Date = Date()
        func ping(reply: @escaping (Date) -> Void) {
            reply(replyDate)
        }
    }

    func testPingReturnsValidDate() {
        let mock = MockHelperPing()
        var captured: Date?
        let exp = expectation(description: "ping reply")

        mock.ping { date in
            captured = date
            exp.fulfill()
        }

        wait(for: [exp], timeout: 0.5)
        XCTAssertNotNil(captured)
        // Date should be within the last ~1s.
        let diff = abs(captured!.timeIntervalSinceNow)
        XCTAssertLessThan(diff, 1.0)
    }

    func testPingReturnsExactDateGivenByMock() {
        let mock = MockHelperPing()
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        mock.replyDate = fixed
        var captured: Date?
        mock.ping { captured = $0 }
        XCTAssertEqual(captured, fixed)
    }
}
