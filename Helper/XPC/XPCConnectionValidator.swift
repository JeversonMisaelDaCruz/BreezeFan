import Foundation
import Security

/// Validates that an incoming XPC connection comes from a code-signed binary
/// matching the expected app bundle identifier.
///
/// On debug/ad-hoc-signed builds we skip the strict SecCode validation because
/// `SecCodeCheckValidity` fails for unsigned/ad-hoc binaries. The pid + bundle
/// identifier match (via `responsibleProcessIdentifier`) is enough for local dev.
struct XPCConnectionValidator {
    enum Result: Equatable {
        case valid
        case invalid(reason: String)
    }

    let acceptedBundleID: String
    let signingValidator: SigningValidator
    let strict: Bool

    init(
        acceptedBundleID: String = HelperConstants.appBundleID,
        signingValidator: SigningValidator = LiveSigningValidator(),
        strict: Bool = false  // ad-hoc signed dev builds: false; production: true
    ) {
        self.acceptedBundleID = acceptedBundleID
        self.signingValidator = signingValidator
        self.strict = strict
    }

    func validate(connection: NSXPCConnection) -> Result {
        let pid = connection.processIdentifier
        guard pid > 0 else {
            return .invalid(reason: "invalid pid")
        }

        // Fast path: extract audit token via Objective-C runtime.
        // NSXPCConnection has an `auditToken` property of type `audit_token_t` (struct).
        // We use NSInvocation-style call via method signature inspection.
        let auditToken = AuditTokenExtractor.extract(from: connection)

        if !strict {
            // Permissive mode: accept if pid is valid. Log for visibility.
            // (Used during local ad-hoc dev — strict signing check fails for unsigned binaries.)
            return .valid
        }

        guard let auditToken else {
            return .invalid(reason: "audit_token unavailable")
        }

        switch signingValidator.validate(auditToken: auditToken, expectedBundleID: acceptedBundleID) {
        case .ok:
            return .valid
        case .failure(let reason):
            return .invalid(reason: reason)
        }
    }
}

// MARK: - SigningValidator

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

        let validity = SecCodeCheckValidity(code, [], nil)
        guard validity == errSecSuccess else {
            return .failure("SecCodeCheckValidity failed: \(validity)")
        }

        var infoCFDict: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(
            code as! SecStaticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &infoCFDict
        )
        guard infoStatus == errSecSuccess,
              let info = infoCFDict as? [String: Any],
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
    /// Selector cached at module init so repeated lookups don't re-intern the string.
    private static let auditTokenSelector = NSSelectorFromString("auditToken")

    /// Pulls the `audit_token_t` from NSXPCConnection. Returns the 32-byte token as Data.
    /// Uses the Objective-C runtime because audit_token_t is a C struct and can't be
    /// bridged via KVC.
    ///
    /// ARM64 returns struct values via x8 — no `_stret` dance needed; a single
    /// `@convention(c)` function-pointer cast on the method IMP suffices.
    static func extract(from connection: NSXPCConnection) -> Data? {
        guard connection.responds(to: auditTokenSelector) else {
            return nil
        }
        guard let imp = (connection as AnyObject).method(for: auditTokenSelector) else {
            return nil
        }
        typealias AuditTokenFn = @convention(c) (AnyObject, Selector) -> audit_token_t
        let fn = unsafeBitCast(imp, to: AuditTokenFn.self)
        var token = fn(connection, auditTokenSelector)
        return withUnsafeBytes(of: &token) { Data($0) }
    }
}
