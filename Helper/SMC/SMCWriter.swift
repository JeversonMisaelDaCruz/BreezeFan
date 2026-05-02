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
    private let queue = DispatchQueue(label: "com.fancontrol.helper.smc.writer")

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
        let bytes: [UInt8]
        switch key.dataType {
        case .fpe2:
            bytes = FPE2.encode(value)
        case .ui8:
            bytes = [UInt8(min(max(0, value.rounded()), 255))]
        case .ui16:
            let v = UInt16(min(max(0, value.rounded()), Double(UInt16.max)))
            bytes = [UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
        default:
            return .failure(.unsupportedDataType(key.dataType.rawValue))
        }
        return doWrite(key: key, bytes: bytes)
    }

    public func writeUInt8(_ key: SMCKey, value: UInt8) -> Result<Void, SMCError> {
        return doWrite(key: key, bytes: [value])
    }

    private func doWrite(key: SMCKey, bytes: [UInt8]) -> Result<Void, SMCError> {
        queue.sync {
            var input = SMCParamStruct()
            input.key = key.fourCC
            input.keyInfo.dataSize = UInt32(bytes.count)
            input.data8 = SMCSelector.kSMCWriteKey

            // Pack `bytes` into SMCBytes tuple.
            withUnsafeMutablePointer(to: &input.bytes) { ptr in
                ptr.withMemoryRebound(to: UInt8.self, capacity: 32) { buf in
                    for (i, b) in bytes.prefix(32).enumerated() {
                        buf[i] = b
                    }
                }
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
}
