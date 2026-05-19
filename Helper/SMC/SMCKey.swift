import Foundation

/// SMC keys are 4-character ASCII identifiers, transmitted as a big-endian UInt32.
/// Table mirrors `crystalidea/macs-fan-control/osx/smc.h` + custom Apple Silicon keys.
public struct SMCKey: Equatable, Hashable, Sendable {
    public let code: String
    public let dataType: DataType

    public enum DataType: String, Sendable {
        case fpe2  // fixed-point 2 bytes
        case ui8   // unsigned 8-bit int
        case ui16  // unsigned 16-bit int big-endian
        case ui32  // unsigned 32-bit int big-endian
        case sp78  // signed fixed-point (Apple Silicon temps)
        case flt   // 32-bit float (Apple Silicon)
    }

    /// Constructs a key from a 4-char ASCII code. Trapping on bad input is
    /// intentional — every call site in this codebase is a 4-char string
    /// literal, so reaching the precondition means a programmer error that
    /// should be caught at runtime in debug builds. For runtime-provided keys
    /// (e.g. from a config file), use ``init(validating:dataType:)`` which
    /// returns `nil` instead.
    public init(_ code: String, _ dataType: DataType = .fpe2) {
        precondition(code.count == 4, "SMC key code must be 4 characters")
        self.code = code
        self.dataType = dataType
    }

    /// Non-trapping init for keys whose source isn't a compile-time literal.
    /// Returns `nil` when `code.count != 4` or the bytes aren't printable ASCII.
    public init?(validating code: String, dataType: DataType = .fpe2) {
        guard code.utf8.count == 4 else { return nil }
        for byte in code.utf8 where byte < 0x20 || byte > 0x7E { return nil }
        self.code = code
        self.dataType = dataType
    }

    /// 4-char string converted to a big-endian UInt32. Used by IOConnectCallStructMethod.
    public var fourCC: UInt32 {
        var result: UInt32 = 0
        for byte in code.utf8 {
            result = (result << 8) | UInt32(byte)
        }
        return result
    }
}

// MARK: - Catalog
public extension SMCKey {
    // Fans
    static let fanCount = SMCKey("FNum", .ui8)

    // Fan 0 (Left)
    static let f0Ac = SMCKey("F0Ac", .fpe2)
    static let f0Md = SMCKey("F0Md", .ui8)
    static let f0Mn = SMCKey("F0Mn", .fpe2)
    static let f0Mx = SMCKey("F0Mx", .fpe2)
    static let f0Tg = SMCKey("F0Tg", .fpe2)

    // Fan 1 (Right)
    static let f1Ac = SMCKey("F1Ac", .fpe2)
    static let f1Md = SMCKey("F1Md", .ui8)
    static let f1Mn = SMCKey("F1Mn", .fpe2)
    static let f1Mx = SMCKey("F1Mx", .fpe2)
    static let f1Tg = SMCKey("F1Tg", .fpe2)

    // CPU performance cluster temperatures (Apple Silicon M1 Pro)
    static let tp01 = SMCKey("Tp01", .sp78)
    static let tp05 = SMCKey("Tp05", .sp78)
    static let tp09 = SMCKey("Tp09", .sp78)
    static let tp0D = SMCKey("Tp0D", .sp78)
    static let tp0H = SMCKey("Tp0H", .sp78)

    // GPU clusters
    static let tg05 = SMCKey("Tg05", .sp78)
    static let tg0D = SMCKey("Tg0D", .sp78)

    /// Legacy alias kept for any external reference; new code reads
    /// temperature keys from the active `ModelProfile.tempKeys`.
    static let cpuPerfClusters: [SMCKey] = [.tp01, .tp05, .tp09, .tp0D, .tp0H]
}
