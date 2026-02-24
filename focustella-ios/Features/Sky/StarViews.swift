import SwiftUI

struct StaticStar: View {
    let position: CGPoint
    let color: StarColor

    var body: some View {
        TwinkleStarShape(points: 4, innerRatio: 0.45)
            .fill(color.primary)
            .frame(width: 8, height: 8)
            .shadow(color: color.glow(opacity: 0.7), radius: 3)
            .opacity(0.9)
            .position(position)
    }
}

struct TwinklingStar: View {
    let position: CGPoint
    let size: CGFloat
    let phaseOffset: Double
    let color: StarColor
    let timeOverride: TimeInterval?

    var body: some View {
        TimelineView(.animation) { context in
            let baseTime = timeOverride ?? context.date.timeIntervalSinceReferenceDate
            let t = baseTime + phaseOffset
            let pulse = (sin(t * 1.6) + 1) / 2
            let opacity = 0.6 + 0.4 * pulse
            let glow = 1.0 + 6.0 * pulse
            let flicker = (sin(t * 0.7 + phaseOffset * 2.0) + 1) / 2
            let glowOpacity = 0.2 + 0.8 * flicker

            TwinkleStarShape(points: 4, innerRatio: 0.45)
                .fill(color.primary)
                .frame(width: size, height: size)
                .shadow(color: color.glow(opacity: glowOpacity), radius: glow)
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
    var primary: Color {
        switch self {
        case .warmYellow:
            return Color(red: 1.0, green: 0.97, blue: 0.8)
        case .paleBlue:
            return Color(red: 0.75, green: 0.85, blue: 1.0)
        }
    }

    func glow(opacity: Double) -> Color {
        switch self {
        case .warmYellow:
            return Color(red: 1.0, green: 0.98, blue: 0.9, opacity: opacity)
        case .paleBlue:
            return Color(red: 0.78, green: 0.88, blue: 1.0, opacity: opacity)
        }
    }
}
