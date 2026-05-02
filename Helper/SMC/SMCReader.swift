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
public final class SMCReaderImpl: SMCReading, @unchecked Sendable {
    private var connection: io_connect_t = 0
    private let queue = DispatchQueue(label: "com.breezefan.helper.smc.reader")

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
            // Step 1: read key info to discover data size + type.
            var input = SMCParamStruct()
            input.key = key.fourCC
            input.data8 = 9 // kSMCGetKeyInfo

            switch callStructMethod(input: input) {
            case .failure(let err): return .failure(err)
            case .success(let info):
                let dataSize = Int(info.keyInfo.dataSize)
                let dataType = info.keyInfo.dataType

                // Step 2: read the actual value.
                var readInput = SMCParamStruct()
                readInput.key = key.fourCC
                readInput.keyInfo.dataSize = info.keyInfo.dataSize
                readInput.data8 = SMCSelector.kSMCReadKey

                switch callStructMethod(input: readInput) {
                case .failure(let err): return .failure(err)
                case .success(let output):
                    return decodeDynamic(bytes: output.bytes, count: dataSize, raw: dataType)
                }
            }
        }
    }

    // MARK: - Decoding (uses runtime-reported type from SMC)

    /// Decodes the bytes based on the FourCC type code returned by SMC at read-time.
    /// On Apple Silicon, F0Mx/F0Mn are usually `flt ` (float), F0Ac/F0Tg are `flt ` too.
    /// On Intel, fan keys are `fpe2`. We honor whatever the SMC reports.
    private func decodeDynamic(bytes: SMCBytes, count: Int, raw: UInt32) -> Result<Double, SMCError> {
        let arr = bytes.toArray(count: count)
        // FourCC codes (ASCII big-endian):
        //   "fpe2" = 0x66706532, "flt " = 0x666C7420, "ui8 " = 0x75693820,
        //   "ui16" = 0x75693136, "ui32" = 0x75693332, "sp78" = 0x73703738,
        //   "si16" = 0x73693136, "si8 " = 0x73693820
        switch raw {
        case 0x666C7420: // "flt "
            guard arr.count >= 4 else { return .failure(.decodingFailed) }
            let v = arr.prefix(4).withUnsafeBytes { ptr -> Float in
                ptr.load(as: Float.self)
            }
            return .success(Double(v))

        case 0x66706532: // "fpe2"
            return .success(FPE2.decode(arr))

        case 0x73703738: // "sp78"
            guard arr.count >= 2 else { return .failure(.decodingFailed) }
            let i16 = Int16(bitPattern: (UInt16(arr[0]) << 8) | UInt16(arr[1]))
            return .success(Double(i16) / 256.0)

        case 0x75693820: // "ui8 "
            guard arr.count >= 1 else { return .failure(.decodingFailed) }
            return .success(Double(arr[0]))

        case 0x75693136: // "ui16"
            guard arr.count >= 2 else { return .failure(.decodingFailed) }
            return .success(Double(UInt16(arr[0]) << 8 | UInt16(arr[1])))

        case 0x75693332: // "ui32"
            guard arr.count >= 4 else { return .failure(.decodingFailed) }
            let v = (UInt32(arr[0]) << 24) | (UInt32(arr[1]) << 16) | (UInt32(arr[2]) << 8) | UInt32(arr[3])
            return .success(Double(v))

        case 0x73693136: // "si16"
            guard arr.count >= 2 else { return .failure(.decodingFailed) }
            let i16 = Int16(bitPattern: (UInt16(arr[0]) << 8) | UInt16(arr[1]))
            return .success(Double(i16))

        case 0x73693820: // "si8 "
            guard arr.count >= 1 else { return .failure(.decodingFailed) }
            return .success(Double(Int8(bitPattern: arr[0])))

        default:
            // Fallback: if SMC reports a type we don't know but we got 4 bytes, try float.
            if arr.count == 4 {
                let v = arr.withUnsafeBytes { ptr -> Float in ptr.load(as: Float.self) }
                if v.isFinite, v >= 0, v < 1_000_000 {
                    return .success(Double(v))
                }
            }
            // Or if we got 2 bytes, try FPE2.
            if arr.count == 2 {
                return .success(FPE2.decode(arr))
            }
            HelperLogger.smc.warn("SMC unknown dataType FourCC=\(String(format: "0x%08x", raw)) for \(count) bytes")
            return .failure(.unsupportedDataType(String(format: "0x%08x", raw)))
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
struct SMCBytes {
    var b: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
         0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0)

    func toArray(count: Int) -> [UInt8] {
        let mirror = Mirror(reflecting: b)
        var out: [UInt8] = []
        out.reserveCapacity(count)
        var i = 0
        for child in mirror.children {
            if i >= count { break }
            if let byte = child.value as? UInt8 {
                out.append(byte)
            }
            i += 1
        }
        return out
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
