import Foundation
import IOKit

/// Reads SMC keys via IOKit. Protocol-based to allow mock injection in tests.
public protocol SMCReading: AnyObject {
    func read(_ key: SMCKey) -> Result<Double, SMCError>
}

/// IOConnect selector codes (constants extracted from Apple's `applesmc.h`).
enum SMCSelector {
    static let kSMCHandleYPCEvent: UInt32 = 2
    static let kSMCReadKey: UInt8 = 5
    static let kSMCWriteKey: UInt8 = 6
}

/// Live SMC reader. Opens a connection to `AppleSMC` service via IOServiceOpen.
///
/// Performance notes:
/// - Key info (dataSize + dataType) is cached after the first read per key. Subsequent reads
///   skip the kSMCGetKeyInfo round trip and issue a single IOConnectCallStructMethod.
/// - Decode is zero-allocation: we read directly from the SMCBytes tuple via an unsafe
///   pointer instead of materializing a [UInt8] every call.
public final class SMCReaderImpl: SMCReading, @unchecked Sendable {
    private var connection: io_connect_t = 0
    private let queue = DispatchQueue(label: "com.breezefan.helper.smc.reader")

    /// Cache of key info, populated lazily. Guarded by `queue`.
    private var keyInfoCache: [UInt32: (size: UInt32, type: UInt32)] = [:]

    public init() throws {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC")
        )
        guard service != 0 else {
            throw SMCError.serviceUnavailable
        }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        let status = IOServiceOpen(service, mach_task_self_, 0, &conn)
        guard status == KERN_SUCCESS, conn != 0 else {
            throw SMCError.openConnectionFailed(kern: status)
        }
        self.connection = conn
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    public func read(_ key: SMCKey) -> Result<Double, SMCError> {
        queue.sync {
            let fourCC = key.fourCC
            let info: (size: UInt32, type: UInt32)
            if let cached = keyInfoCache[fourCC] {
                info = cached
            } else {
                var probe = SMCParamStruct()
                probe.key = fourCC
                probe.data8 = 9 // kSMCGetKeyInfo
                switch callStructMethod(input: probe) {
                case .failure(let err): return .failure(err)
                case .success(let probed):
                    info = (probed.keyInfo.dataSize, probed.keyInfo.dataType)
                    keyInfoCache[fourCC] = info
                }
            }

            var readInput = SMCParamStruct()
            readInput.key = fourCC
            readInput.keyInfo.dataSize = info.size
            readInput.data8 = SMCSelector.kSMCReadKey

            switch callStructMethod(input: readInput) {
            case .failure(let err): return .failure(err)
            case .success(var output):
                return decodeDynamic(bytes: &output.bytes, count: Int(info.size), raw: info.type)
            }
        }
    }

    // MARK: - Decoding (uses runtime-reported type from SMC)

    /// Decodes the bytes based on the FourCC type code returned by SMC at read-time.
    /// Zero allocation: reads directly from the 32-byte tuple via an unsafe pointer.
    /// On Apple Silicon, F0Mx/F0Mn are usually `flt ` (float), F0Ac/F0Tg are `flt ` too.
    /// On Intel, fan keys are `fpe2`. We honor whatever the SMC reports.
    private func decodeDynamic(bytes: inout SMCBytes, count: Int, raw: UInt32) -> Result<Double, SMCError> {
        bytes.withRawBytes { ptr in
            // FourCC codes (ASCII big-endian):
            //   "fpe2" = 0x66706532, "flt " = 0x666C7420, "ui8 " = 0x75693820,
            //   "ui16" = 0x75693136, "ui32" = 0x75693332, "sp78" = 0x73703738,
            //   "si16" = 0x73693136, "si8 " = 0x73693820
            switch raw {
            case 0x666C7420: // "flt " — little-endian on Apple Silicon
                guard count >= 4 else { return .failure(.decodingFailed) }
                var f: Float = 0
                memcpy(&f, ptr, 4)
                return .success(Double(f))

            case 0x66706532: // "fpe2" — big-endian fixed-point
                guard count >= 2 else { return .failure(.decodingFailed) }
                let raw16 = (UInt16(ptr[0]) << 8) | UInt16(ptr[1])
                return .success(Double(raw16) / 4.0)

            case 0x73703738: // "sp78"
                guard count >= 2 else { return .failure(.decodingFailed) }
                let i16 = Int16(bitPattern: (UInt16(ptr[0]) << 8) | UInt16(ptr[1]))
                return .success(Double(i16) / 256.0)

            case 0x75693820: // "ui8 "
                guard count >= 1 else { return .failure(.decodingFailed) }
                return .success(Double(ptr[0]))

            case 0x75693136: // "ui16"
                guard count >= 2 else { return .failure(.decodingFailed) }
                return .success(Double(UInt16(ptr[0]) << 8 | UInt16(ptr[1])))

            case 0x75693332: // "ui32"
                guard count >= 4 else { return .failure(.decodingFailed) }
                let v = (UInt32(ptr[0]) << 24) | (UInt32(ptr[1]) << 16) | (UInt32(ptr[2]) << 8) | UInt32(ptr[3])
                return .success(Double(v))

            case 0x73693136: // "si16"
                guard count >= 2 else { return .failure(.decodingFailed) }
                let i16 = Int16(bitPattern: (UInt16(ptr[0]) << 8) | UInt16(ptr[1]))
                return .success(Double(i16))

            case 0x73693820: // "si8 "
                guard count >= 1 else { return .failure(.decodingFailed) }
                return .success(Double(Int8(bitPattern: ptr[0])))

            default:
                // Fallback: 4 bytes → float, 2 bytes → fpe2.
                if count == 4 {
                    var f: Float = 0
                    memcpy(&f, ptr, 4)
                    if f.isFinite, f >= 0, f < 1_000_000 {
                        return .success(Double(f))
                    }
                }
                if count == 2 {
                    let raw16 = (UInt16(ptr[0]) << 8) | UInt16(ptr[1])
                    return .success(Double(raw16) / 4.0)
                }
                HelperLogger.smc.warn("SMC unknown dataType FourCC=\(String(format: "0x%08x", raw)) for \(count) bytes")
                return .failure(.unsupportedDataType(String(format: "0x%08x", raw)))
            }
        }
    }

    // MARK: - IOConnect call

    private func callStructMethod(input: SMCParamStruct) -> Result<SMCParamStruct, SMCError> {
        var input = input
        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.size

        let result = withUnsafePointer(to: &input) { inPtr -> kern_return_t in
            withUnsafeMutablePointer(to: &output) { outPtr in
                IOConnectCallStructMethod(
                    connection,
                    SMCSelector.kSMCHandleYPCEvent,
                    inPtr,
                    MemoryLayout<SMCParamStruct>.size,
                    outPtr,
                    &outputSize
                )
            }
        }

        if result == KERN_SUCCESS {
            // Check inner result code.
            let inner = output.result
            if inner == 0x84 { // kIOReturnExclusiveAccess
                return .failure(.locked)
            }
            if inner != 0 {
                return .failure(.readFailed(kern: Int32(bitPattern: UInt32(inner))))
            }
            return .success(output)
        }

        if result == KERN_NO_ACCESS {
            return .failure(.locked)
        }
        return .failure(.readFailed(kern: result))
    }
}

// MARK: - SMC parameter struct (80 bytes, matches kernel layout)

struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

struct SMCVersion {
    var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0
    var release: UInt16 = 0
}

struct SMCPLimitData {
    var version: UInt16 = 0, length: UInt16 = 0, cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0, memPLimit: UInt32 = 0
}

/// Fixed-size 32-byte data buffer used for SMC key reads/writes.
///
/// Decoding/encoding helpers operate via an unsafe pointer over the tuple's storage —
/// no `[UInt8]` allocations or `Mirror` reflection on the hot path.
struct SMCBytes {
    var b: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
         0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0)

    /// Read-only raw pointer over the 32-byte tuple. Zero-allocation.
    @inline(__always)
    mutating func withRawBytes<R>(_ body: (UnsafePointer<UInt8>) -> R) -> R {
        return withUnsafePointer(to: &b) { tuplePtr in
            tuplePtr.withMemoryRebound(to: UInt8.self, capacity: 32) { body($0) }
        }
    }

    /// Mutable raw pointer over the 32-byte tuple. Zero-allocation, used for writes.
    @inline(__always)
    mutating func withMutableRawBytes<R>(_ body: (UnsafeMutablePointer<UInt8>) -> R) -> R {
        return withUnsafeMutablePointer(to: &b) { tuplePtr in
            tuplePtr.withMemoryRebound(to: UInt8.self, capacity: 32) { body($0) }
        }
    }
}

struct SMCParamStruct {
    var key: UInt32 = 0
    var vers: SMCVersion = SMCVersion()
    var pLimitData: SMCPLimitData = SMCPLimitData()
    var keyInfo: SMCKeyInfoData = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = SMCBytes()
}
