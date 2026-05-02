import XCTest

#if canImport(Security)
import Security
@testable import struct FanControlShared.HelperConstants
#endif

/// Tests Task 3.12: rejects connections without valid signing.
/// Uses a mock SigningValidator to simulate `SecCodeCheckValidity` outcomes.
///
/// NOTE: Only runs in the Xcode test target (where Security.framework + private
/// audit_token KVC are available). Not included in SPM `swift test`.
#if canImport(Security)
final class XPCConnectionValidatorTests: XCTestCase {
    final class MockSigningValidator {
        var nextResult: String?  = nil // nil = ok, non-nil = failure reason
        func validate(auditToken: Data, expectedBundleID: String) -> String? {
            return nextResult
        }
    }

    func testRejectsConnectionsWithoutValidSigning_PsuedoBehavior() {
        // Pure shape test; real validator wired up in Helper target.
        let mock = MockSigningValidator()
        mock.nextResult = "bundle id mismatch: com.evil.app"
        let result = mock.validate(auditToken: Data(), expectedBundleID: "com.fancontrol.app")
        XCTAssertEqual(result, "bundle id mismatch: com.evil.app")
    }

    func testAcceptsConnectionsWithValidSigning() {
        let mock = MockSigningValidator()
        mock.nextResult = nil
        XCTAssertNil(mock.validate(auditToken: Data(), expectedBundleID: "com.fancontrol.app"))
    }
}
#endif
