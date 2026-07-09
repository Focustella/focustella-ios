import CoreGraphics
import Foundation

enum MySkyStarSizeScale {
    private static let lowerBound: CGFloat = 0.94
    private static let upperBound: CGFloat = 1.10

    static func scale(userSeed: Int, constellationId: UUID, starId: UUID) -> CGFloat {
        var hash: UInt64 = 0xcbf29ce484222325
        combine(UInt64(bitPattern: Int64(userSeed)), into: &hash)
        combine(constellationId.uuidString, into: &hash)
        combine(starId.uuidString, into: &hash)

        let unit = CGFloat(hash % 10_000) / 9_999
        return lowerBound + ((upperBound - lowerBound) * unit)
    }

    private static func combine(_ value: UInt64, into hash: inout UInt64) {
        for shift in stride(from: 0, through: 56, by: 8) {
            hash ^= (value >> UInt64(shift)) & 0xff
            hash &*= 0x100000001b3
        }
    }

    private static func combine(_ value: String, into hash: inout UInt64) {
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
    }
}
