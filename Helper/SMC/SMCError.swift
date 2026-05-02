import Foundation

public enum SMCError: Error, Equatable, Sendable {
    case serviceUnavailable
    case openConnectionFailed(kern: Int32)
    case keyNotFound(String)
    case readFailed(kern: Int32)
    case writeFailed(kern: Int32)
    case locked  // kIOReturnExclusiveAccess
    case decodingFailed
    case unsupportedDataType(String)
}
