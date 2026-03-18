import SwiftUI

struct AmbientStar: Identifiable {
    let id: UUID = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let phase: Double
    let baseOpacity: Double
    let baseGlow: CGFloat
    let color: Color
    let hasFlare: Bool
    let flareAngle: Double

    static func makeSeeded(count: Int, seed: UInt64) -> [AmbientStar] {
        var generator = SeededRNG(state: seed == 0 ? 0xA1B2C3D4 : seed)
        return (0..<count).map { _ in
            let x = generator.nextCGFloat(in: 0.02...0.98)
            let y = generator.nextCGFloat(in: 0.04...0.96)
            let size = generator.nextCGFloat(in: 1.5...3.3)
            let phase = generator.nextDouble(in: 0...(Double.pi * 2))
            let baseOpacity = generator.nextDouble(in: 0.16...0.42)
            let baseGlow = generator.nextCGFloat(in: 1.2...3.4)
            let color = ambientColor(index: Int(generator.next() % 4))
            let hasFlare = size > 2.5 && (generator.next() % 11 == 0)
            let flareAngle = generator.nextDouble(in: 0...180)
            return AmbientStar(
                x: x,
                y: y,
                size: size,
                phase: phase,
                baseOpacity: baseOpacity,
                baseGlow: baseGlow,
                color: color,
                hasFlare: hasFlare,
                flareAngle: flareAngle
            )
        }
    }

    private static func ambientColor(index: Int) -> Color {
        switch index {
        case 0:
            return Color(red: 0.78, green: 0.92, blue: 1.0)
        case 1:
            return Color(red: 0.72, green: 0.88, blue: 1.0)
        case 2:
            return Color(red: 0.86, green: 0.95, blue: 1.0)
        default:
            return Color(red: 0.82, green: 0.9, blue: 1.0)
        }
    }
}

struct SeededRNG {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let ratio = Double(next() & 0xFFFF_FFFF) / Double(UInt32.max)
        return range.lowerBound + ratio * (range.upperBound - range.lowerBound)
    }

    mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let ratio = Double(next() & 0xFFFF_FFFF) / Double(UInt32.max)
        return range.lowerBound + CGFloat(ratio) * (range.upperBound - range.lowerBound)
    }
}
