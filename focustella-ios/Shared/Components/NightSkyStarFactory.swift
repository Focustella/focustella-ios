import SwiftUI

struct NightSkyStarSpec: Hashable {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let glowRadius: CGFloat
}

struct NightSkyStarProfile: Hashable {
    let xRange: ClosedRange<CGFloat>
    let yRange: ClosedRange<CGFloat>
    let sizeRange: ClosedRange<CGFloat>
    let opacityRange: ClosedRange<Double>
    let glowRadiusRange: ClosedRange<CGFloat>

    static let standard = NightSkyStarProfile(
        xRange: 0.02...0.98,
        yRange: 0.03...0.97,
        sizeRange: 1.2...3.2,
        opacityRange: 0.16...0.52,
        glowRadiusRange: 1.0...3.0
    )

    static let denseUpper = NightSkyStarProfile(
        xRange: 0.02...0.98,
        yRange: 0.02...0.88,
        sizeRange: 1.0...2.8,
        opacityRange: 0.14...0.50,
        glowRadiusRange: 0.8...2.6
    )

    static let wideSoft = NightSkyStarProfile(
        xRange: 0.01...0.99,
        yRange: 0.02...0.98,
        sizeRange: 1.1...3.5,
        opacityRange: 0.12...0.46,
        glowRadiusRange: 1.2...3.4
    )
}

enum NightSkyStarFactory {
    private static let fallbackSeed: UInt64 = 0xCAFE_BABE
    private static let userSeedKey = "userSeed"

    static func makeStars(
        count: Int,
        seed: UInt64? = nil,
        salt: String = "night-sky-stars",
        profile: NightSkyStarProfile = .standard
    ) -> [NightSkyStarSpec] {
        guard count > 0 else { return [] }
        let resolved = mixedSeed(baseSeed(seed), salt: salt)
        var generator = NightSkyBackgroundRNG(state: resolved)
        return (0..<count).map { _ in
            NightSkyStarSpec(
                x: generator.nextCGFloat(in: profile.xRange),
                y: generator.nextCGFloat(in: profile.yRange),
                size: generator.nextCGFloat(in: profile.sizeRange),
                opacity: generator.nextDouble(in: profile.opacityRange),
                glowRadius: generator.nextCGFloat(in: profile.glowRadiusRange)
            )
        }
    }

    static func userSeed() -> UInt64 {
        guard let raw = UserDefaults.standard.object(forKey: userSeedKey) as? NSNumber else {
            return fallbackSeed
        }
        let seed = UInt64(bitPattern: raw.int64Value)
        return seed == 0 ? fallbackSeed : seed
    }

    private static func baseSeed(_ seed: UInt64?) -> UInt64 {
        let resolved = seed ?? userSeed()
        return resolved == 0 ? fallbackSeed : resolved
    }

    private static func mixedSeed(_ seed: UInt64, salt: String) -> UInt64 {
        var state = seed ^ 0x9E37_79B9_7F4A_7C15
        for byte in salt.utf8 {
            state ^= UInt64(byte)
            state &*= 1_099_511_628_211
            state ^= state >> 32
        }
        return state == 0 ? fallbackSeed : state
    }
}

private struct NightSkyBackgroundRNG {
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
