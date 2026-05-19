import Foundation
import IOKit

/// Writes SMC keys via IOKit. Protocol-based for mock injection.
public protocol SMCWriting: AnyObject {
    /// Writes a numeric value to the given key. Encoding follows the key's `dataType`.
    func write(_ key: SMCKey, value: Double) -> Result<Void, SMCError>

    /// Writes a raw UInt8 (for mode keys F0Md/F1Md = 0|1).
    func writeUInt8(_ key: SMCKey, value: UInt8) -> Result<Void, SMCError>
}

public final class SMCWriterImpl: SMCWriting, @unchecked Sendable {
    private var connection: io_connect_t = 0
    private let queue = DispatchQueue(label: "com.breezefan.helper.smc.writer")

    /// Cache of key info (dataSize, dataType), populated lazily on first probe.
    /// Guarded by `queue`. Eliminates the per-write kSMCGetKeyInfo round trip.
    private var keyInfoCache: [UInt32: (size: UInt32, type: UInt32)] = [:]

    public init() throws {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC")
        )
        guard service != 0 else { throw SMCError.serviceUnavailable }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        let status = IOServiceOpen(service, mach_task_self_, 0, &conn)
        guard status == KERN_SUCCESS, conn != 0 else {
            throw SMCError.openConnectionFailed(kern: status)
        }
        self.connection = conn
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    public func write(_ key: SMCKey, value: Double) -> Result<Void, SMCError> {
        return queue.sync { () -> Result<Void, SMCError> in
            let fourCC = key.fourCC
            let info: (size: UInt32, type: UInt32)
            if let cached = keyInfoCache[fourCC] {
                info = cached
            } else {
                var probe = SMCParamStruct()
                probe.key = fourCC
                probe.data8 = 9 // kSMCGetKeyInfo

                var probeOut = SMCParamStruct()
                var probeSize = MemoryLayout<SMCParamStruct>.size
                let probeStatus = withUnsafePointer(to: &probe) { inPtr in
                    withUnsafeMutablePointer(to: &probeOut) { outPtr in
                        IOConnectCallStructMethod(connection, SMCSelector.kSMCHandleYPCEvent,
                                                  inPtr, MemoryLayout<SMCParamStruct>.size,
                                                  outPtr, &probeSize)
                    }
                }
                guard probeStatus == KERN_SUCCESS, probeOut.result == 0 else {
                    return .failure(.writeFailed(kern: probeStatus))
                }
                info = (probeOut.keyInfo.dataSize, probeOut.keyInfo.dataType)
                keyInfoCache[fourCC] = info
            }

            let bytes: [UInt8]
            switch info.type {
            case 0x666C7420: // "flt " — most fan keys on Apple Silicon
                let f = Float(value)
                bytes = withUnsafeBytes(of: f) { Array($0) }
            case 0x66706532: // "fpe2" — Intel fan keys
                bytes = FPE2.encode(value)
            case 0x75693820: // "ui8 "
                bytes = [UInt8(min(max(0, value.rounded()), 255))]
            case 0x75693136: // "ui16"
                let v = UInt16(min(max(0, value.rounded()), Double(UInt16.max)))
                bytes = [UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
            default:
                HelperLogger.smc.warn("SMCWriter unknown dataType FourCC=\(String(format: "0x%08x", info.type)) for \(key.code)")
                return .failure(.unsupportedDataType(String(format: "0x%08x", info.type)))
            }
            return performWriteLocked(key: key, bytes: bytes, dataSize: info.size)
        }
    }

    public func writeUInt8(_ key: SMCKey, value: UInt8) -> Result<Void, SMCError> {
        return queue.sync {
            // Mode keys (F0Md/F1Md) are ui8 — no probe needed, no cache entry needed either.
            return performWriteLocked(key: key, bytes: [value], dataSize: 1)
        }
    }

    /// Performs the actual write. MUST be invoked while holding `queue` (callers already do).
    private func performWriteLocked(key: SMCKey, bytes: [UInt8], dataSize: UInt32) -> Result<Void, SMCError> {
        var input = SMCParamStruct()
        input.key = key.fourCC
        input.keyInfo.dataSize = dataSize
        input.data8 = SMCSelector.kSMCWriteKey

        // Pack `bytes` into the SMCBytes tuple in place — zero allocation.
        input.bytes.withMutableRawBytes { buf in
            let n = min(bytes.count, 32)
            for i in 0..<n { buf[i] = bytes[i] }
        }

        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.size
        let result = withUnsafePointer(to: &input) { inPtr in
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
            let inner = output.result
            if inner == 0x84 { return .failure(.locked) }
            if inner != 0 {
                return .failure(.writeFailed(kern: Int32(bitPattern: UInt32(inner))))
            }
            return .success(())
        }
        if result == KERN_NO_ACCESS { return .failure(.locked) }
        return .failure(.writeFailed(kern: result))
    }
}
