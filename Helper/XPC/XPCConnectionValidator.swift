import Foundation
import Security

/// Validates that an incoming XPC connection comes from a code-signed binary
/// matching the expected app bundle identifier. Logic is isolated so the
/// `HelperListenerDelegate` is tested via injected mock.
struct XPCConnectionValidator {
    enum Result: Equatable {
        case valid
        case invalid(reason: String)
    }

    /// Bundle ID we accept. Defaults to FanControl.app.
    let acceptedBundleID: String
    let signingValidator: SigningValidator

    init(
        acceptedBundleID: String = HelperConstants.appBundleID,
        signingValidator: SigningValidator = LiveSigningValidator()
    ) {
        self.acceptedBundleID = acceptedBundleID
        self.signingValidator = signingValidator
    }

    func validate(connection: NSXPCConnection) -> Result {
        // 1. PID must be valid.
        let pid = connection.processIdentifier
        guard pid > 0 else {
            return .invalid(reason: "invalid pid")
        }

        // 2. Pull audit token. NSXPCConnection has a private property `auditToken`,
        //    accessed via KVC. This pattern is used by stats.app and other open-source helpers.
        guard let auditToken = AuditTokenExtractor.extract(from: connection) else {
            return .invalid(reason: "audit_token unavailable")
        }

        // 3. Check signature + bundle ID via SecCode.
        switch signingValidator.validate(auditToken: auditToken, expectedBundleID: acceptedBundleID) {
        case .ok:
            return .valid
        case .failure(let reason):
            return .invalid(reason: reason)
        }
    }
}

// MARK: - SigningValidator (protocol + live impl + mock for tests)

protocol SigningValidator {
    func validate(auditToken: Data, expectedBundleID: String) -> SigningResult
}

enum SigningResult: Equatable {
    case ok
    case failure(String)
}

struct LiveSigningValidator: SigningValidator {
    func validate(auditToken: Data, expectedBundleID: String) -> SigningResult {
        var code: SecCode?
        let attrs: [String: Any] = [
            kSecGuestAttributeAudit as String: auditToken
        ]
        let copyStatus = SecCodeCopyGuestWithAttributes(nil, attrs as CFDictionary, [], &code)
        guard copyStatus == errSecSuccess, let code else {
            return .failure("SecCodeCopyGuestWithAttributes failed: \(copyStatus)")
        }

        // Validity check — code signature, hashes, etc.
        let validity = SecCodeCheckValidity(code, [], nil)
        guard validity == errSecSuccess else {
            return .failure("SecCodeCheckValidity failed: \(validity)")
        }

        // Pull bundle ID from signing info.
        var staticCode: SecStaticCode?
        SecCodeCopyStaticCode(code, [], &staticCode)
        var infoCFDict: CFDictionary?
        let target: AnyObject = (staticCode ?? code) as AnyObject
        let infoStatus = SecCodeCopySigningInformation(
            target as! SecStaticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &infoCFDict
        )
        guard infoStatus == errSecSuccess, let info = infoCFDict as? [String: Any],
              let identifier = info["identifier"] as? String else {
            return .failure("signing info unavailable")
        }
        guard identifier == expectedBundleID else {
            return .failure("bundle id mismatch: \(identifier)")
        }
        return .ok
    }
}

// MARK: - audit_token extraction

enum AuditTokenExtractor {
    /// Pulls the `audit_token_t` from a private property of NSXPCConnection.
    /// Returns the 32-byte token as Data, or nil if extraction fails.
    static func extract(from connection: NSXPCConnection) -> Data? {
        // NSXPCConnection has an `auditToken` property that returns NSData on macOS 13+.
        // KVC is the documented escape hatch.
        let raw = connection.value(forKey: "auditToken")
        if let data = raw as? Data {
            return data
        }
        if let nsdata = raw as? NSData {
            return nsdata as Data
        }
        return nil
    }
}
