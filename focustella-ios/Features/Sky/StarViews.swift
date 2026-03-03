import SwiftUI

struct StaticStar: View {
    let position: CGPoint
    let color: StarColor
    let animatesColor: Bool

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = Double(position.x * 0.01 + position.y * 0.02)
            let fillColor = animatesColor ? color.dynamicPrimary(time: t, phaseOffset: phase) : color.primary
            let glowColor = animatesColor
                ? color.dynamicGlow(time: t, phaseOffset: phase, opacity: 0.95)
                : color.glow(opacity: 0.95)

            TwinkleStarShape(points: 4, innerRatio: 0.45)
                .fill(fillColor)
                .frame(width: 10, height: 10)
                .shadow(color: glowColor, radius: 9)
                .opacity(0.9)
                .position(position)
        }
    }
}

struct TwinklingStar: View {
    let position: CGPoint
    let size: CGFloat
    let phaseOffset: Double
    let color: StarColor
    let timeOverride: TimeInterval?
    let animatesColor: Bool

    var body: some View {
        TimelineView(.animation) { context in
            let baseTime = timeOverride ?? context.date.timeIntervalSinceReferenceDate
            let t = baseTime + phaseOffset
            let pulse = (sin(t * 1.6) + 1) / 2
            let opacity = 0.72 + 0.28 * pulse
            let glow = 3.0 + 11.0 * pulse
            let flicker = (sin(t * 0.7 + phaseOffset * 2.0) + 1) / 2
            let glowOpacity = 0.45 + 0.55 * flicker
            let fillColor = animatesColor ? color.dynamicPrimary(time: t, phaseOffset: phaseOffset) : color.primary
            let glowColor = animatesColor
                ? color.dynamicGlow(time: t, phaseOffset: phaseOffset, opacity: glowOpacity)
                : color.glow(opacity: glowOpacity)

            TwinkleStarShape(points: 4, innerRatio: 0.45)
                .fill(fillColor)
                .frame(width: size, height: size)
                .shadow(color: glowColor, radius: glow)
                .opacity(opacity)
                .position(position)
        }
    }
}

struct TwinkleStarShape: Shape {
    let points: Int
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRatio
        let angleStep = .pi * 2 / CGFloat(points * 2)

        var path = Path()
        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = angleStep * CGFloat(index) - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

extension StarColor {
    private static let transitionPalette: [StarColor] = [
        .warmYellow,
        .emberRed,
        .nebulaPurple,
        .paleBlue,
        .aquaCyan
    ]

    private var rgb: (Double, Double, Double) {
        switch self {
        case .warmYellow:
            return (1.0, 0.97, 0.8)
        case .paleBlue:
            return (0.75, 0.85, 1.0)
        case .nebulaPurple:
            return (0.82, 0.66, 1.0)
        case .emberRed:
            return (1.0, 0.56, 0.52)
        case .aquaCyan:
            return (0.56, 0.95, 0.9)
        }
    }

    private func dynamicRGB(time: TimeInterval, phaseOffset: Double) -> (Double, Double, Double) {
        let colors = Self.transitionPalette
        guard let baseIndex = colors.firstIndex(of: self) else { return rgb }

        // Slow color drift (roughly 16 seconds per full cycle).
        let cycle = 16.0
        let normalized = (time / cycle + phaseOffset * 0.05).truncatingRemainder(dividingBy: 1.0)
        let segmentProgress = normalized * Double(colors.count)
        let step = Int(segmentProgress) % colors.count
        let t = segmentProgress - floor(segmentProgress)

        let from = colors[(baseIndex + step) % colors.count].rgb
        let to = colors[(baseIndex + step + 1) % colors.count].rgb
        return (
            from.0 + (to.0 - from.0) * t,
            from.1 + (to.1 - from.1) * t,
            from.2 + (to.2 - from.2) * t
        )
    }

    func dynamicPrimary(time: TimeInterval, phaseOffset: Double) -> Color {
        let c = dynamicRGB(time: time, phaseOffset: phaseOffset)
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    func dynamicGlow(time: TimeInterval, phaseOffset: Double, opacity: Double) -> Color {
        let c = dynamicRGB(time: time, phaseOffset: phaseOffset)
        return Color(red: min(c.0 + 0.04, 1.0), green: min(c.1 + 0.04, 1.0), blue: min(c.2 + 0.04, 1.0), opacity: opacity)
    }

    var primary: Color {
        switch self {
        case .warmYellow:
            return Color(red: 1.0, green: 0.97, blue: 0.8)
        case .paleBlue:
            return Color(red: 0.75, green: 0.85, blue: 1.0)
        case .nebulaPurple:
            return Color(red: 0.82, green: 0.66, blue: 1.0)
        case .emberRed:
            return Color(red: 1.0, green: 0.56, blue: 0.52)
        case .aquaCyan:
            return Color(red: 0.56, green: 0.95, blue: 0.9)
        }
    }

    func glow(opacity: Double) -> Color {
        switch self {
        case .warmYellow:
            return Color(red: 1.0, green: 0.98, blue: 0.9, opacity: opacity)
        case .paleBlue:
            return Color(red: 0.78, green: 0.88, blue: 1.0, opacity: opacity)
        case .nebulaPurple:
            return Color(red: 0.84, green: 0.7, blue: 1.0, opacity: opacity)
        case .emberRed:
            return Color(red: 1.0, green: 0.62, blue: 0.58, opacity: opacity)
        case .aquaCyan:
            return Color(red: 0.62, green: 0.97, blue: 0.92, opacity: opacity)
        }
    }
}
