import Foundation

/// SMC `FPE2` fixed-point encoding: 14 bits integer + 2 bits fraction in the high byte,
/// then 8 fraction bits in the low byte. Used by RPM and many temperature keys.
///
/// Layout (big-endian, 16 bits total):
///     byte[0]: bits 15..2 = integer high; bits 1..0 = top of fraction
///     byte[1]: 8 bits low fraction
///
/// In practice for SMC values: integer = (byte[0] << 6) | (byte[1] >> 2);
/// fraction = ((byte[0] & 0x3) << 6) | (byte[1] & 0x3F) — we approximate via
/// dividing the raw 16-bit big-endian value by 4 (== shift right 2 bits) since
/// the 2 fraction bits live at the bottom of the high byte.
public enum FPE2 {
    /// Decode 2 SMC bytes into a Double value.
    public static func decode(_ bytes: [UInt8]) -> Double {
        guard bytes.count >= 2 else { return 0 }
        let high = UInt16(bytes[0])
        let low  = UInt16(bytes[1])
        let raw  = (high << 8) | low
        return Double(raw) / 4.0
    }

    public static func decode(_ data: Data) -> Double {
        guard data.count >= 2 else { return 0 }
        let bytes = [data[data.startIndex], data[data.startIndex + 1]]
        return decode(bytes)
    }

    /// Encode a Double into SMC FPE2 (2 bytes). Negative values clamped to 0.
    public static func encode(_ value: Double) -> [UInt8] {
        let clamped = max(0, value)
        let scaled = UInt32((clamped * 4.0).rounded())
        let truncated = min(scaled, UInt32(UInt16.max))
        let raw = UInt16(truncated)
        return [UInt8((raw >> 8) & 0xFF), UInt8(raw & 0xFF)]
    }

    public static func encodeData(_ value: Double) -> Data {
        Data(encode(value))
    }
}
