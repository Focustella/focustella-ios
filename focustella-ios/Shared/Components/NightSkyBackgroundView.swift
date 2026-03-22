import SwiftUI

struct NightSkyBackgroundView: View {
    let style: NightSkyBackgroundStyle
    var extendsIntoSafeArea: Bool = true

    var body: some View {
        let background = backgroundContent.allowsHitTesting(false)

        if extendsIntoSafeArea {
            background.ignoresSafeArea()
        } else {
            background
        }
    }

    @ViewBuilder
    private var backgroundContent: some View {
        switch style {
        case .demo:
            DemoNightSkyBackgroundView()
        case .mySkyFocusStar:
            FocusStarSkyBackgroundView()
        case .mySkyLegacy:
            LegacyMySkyBackgroundView()
        }
    }
}

enum NightSkyBackgroundStyle {
    case demo
    case mySkyFocusStar
    case mySkyLegacy
}

struct NightSkyStarField: View {
    let seed: UInt64
    let count: Int

    private var stars: [NightSkyStar] {
        var generator = NightSkyBackgroundRNG(state: seed == 0 ? 0xCAFEBABE : seed)
        return (0..<count).map { _ in
            NightSkyStar(
                x: generator.nextCGFloat(in: 0.02...0.98),
                y: generator.nextCGFloat(in: 0.03...0.97),
                size: generator.nextCGFloat(in: 1.2...3.2),
                opacity: generator.nextDouble(in: 0.16...0.52),
                glowRadius: generator.nextCGFloat(in: 1.0...3.0)
            )
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(stars.enumerated()), id: \.offset) { _, star in
                    Circle()
                        .fill(Color.white.opacity(star.opacity))
                        .frame(width: star.size, height: star.size)
                        .shadow(color: Color.white.opacity(star.opacity * 0.55), radius: star.glowRadius)
                        .position(x: star.x * proxy.size.width, y: star.y * proxy.size.height)
                }
            }
        }
    }
}

private struct DemoNightSkyBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [FocusStarPalette.demoTop, FocusStarPalette.skyMid, FocusStarPalette.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(FocusStarPalette.goldGlow.opacity(0.16))
                .frame(width: 240, height: 240)
                .blur(radius: 50)
                .offset(x: -140, y: -300)

            Circle()
                .fill(FocusStarPalette.cyanGlow.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 130, y: 260)

            NightSkyStarField(seed: 20260321, count: 72)
        }
    }
}

private struct NightSkyStar {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let glowRadius: CGFloat
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
