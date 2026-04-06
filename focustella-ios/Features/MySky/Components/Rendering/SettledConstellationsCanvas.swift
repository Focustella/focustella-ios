import SwiftUI

struct SettledConstellationsCanvas: View {
    struct Item: Identifiable {
        let constellation: Constellation
        let discoveredStarCount: Int
        let visibleEdgeIndices: Set<Int>
        let edgeVisibilityOverrides: [Int: CGFloat]

        var id: UUID { constellation.id }
    }

    let items: [Item]
    let coordinateMapper: MySkyCoordinateMapper
    let camera: MySkyCameraState
    let starStyle: StarAppearanceStyle
    let reduceMotion: Bool
    let highPerformanceMode: Bool
    let animationTime: TimeInterval?

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, _ in
            let shouldAnimate = highPerformanceMode && !reduceMotion
            let time = animationTime ?? 0

            for item in items {
                drawConstellation(item, in: &context, time: time, shouldAnimate: shouldAnimate)
            }
        }
        .frame(
            width: coordinateMapper.canvasSize.width,
            height: coordinateMapper.canvasSize.height
        )
        .compositingGroup()
        .allowsHitTesting(false)
    }

    private func drawConstellation(_ item: Item, in context: inout GraphicsContext, time: TimeInterval, shouldAnimate: Bool) {
        let pointsById = Dictionary(uniqueKeysWithValues: item.constellation.stars.map { star in
            (
                star.id,
                coordinateMapper.screenPoint(fromSky: CGPoint(x: star.x, y: star.y), camera: camera)
            )
        })
        let basePalette = basePalette(for: item.constellation)
        let discoveredCount = min(item.discoveredStarCount, item.constellation.stars.count)
        let edgePulse = shouldAnimate ? (sin(time * 0.85) + 1) / 2 : 0.35
        let edgeOpacity = shouldAnimate ? (0.11 + 0.08 * edgePulse) : 0.12

        for edgeIndex in item.visibleEdgeIndices.sorted() {
            guard item.constellation.edges.indices.contains(edgeIndex) else { continue }
            let visibility = max(0, min(1, item.edgeVisibilityOverrides[edgeIndex] ?? 1))
            guard visibility > 0 else { continue }

            let edge = item.constellation.edges[edgeIndex]
            guard let from = pointsById[edge.from], let to = pointsById[edge.to] else { continue }

            var path = Path()
            path.move(to: from)
            path.addLine(to: to)

            var glowContext = context
            glowContext.addFilter(.shadow(color: basePalette.color.opacity(edgeOpacity * Double(visibility) * 0.5), radius: shouldAnimate ? 2.6 : 1.8, x: 0, y: 0))
            glowContext.stroke(
                path,
                with: .color(basePalette.color.opacity(edgeOpacity * Double(visibility))),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
            )
        }

        for index in 0..<discoveredCount {
            let star = item.constellation.stars[index]
            let center = coordinateMapper.screenPoint(
                fromSky: CGPoint(x: star.x, y: star.y),
                camera: camera
            )
            let phaseOffset = Double(star.x * 30 + star.y * 15)
            let pulse = shouldAnimate ? (sin((time + phaseOffset) * 1.2) + 1) / 2 : 0.5
            let flicker = shouldAnimate ? (sin((time + phaseOffset) * 0.55 + phaseOffset * 1.6) + 1) / 2 : 0.5
            let palette = palette(for: index, base: basePalette)
            let glowOpacity = shouldAnimate ? (0.24 + 0.16 * flicker) : 0.24
            let starSize: CGFloat = 8.2 + (shouldAnimate ? CGFloat(pulse) * 0.9 : 0)
            let glowRadius: CGFloat = shouldAnimate ? (5.5 + CGFloat(pulse) * 3.4) : 4.2

            let glowRect = CGRect(x: center.x - glowRadius, y: center.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
            var glowContext = context
            glowContext.addFilter(.blur(radius: shouldAnimate ? 4 : 3))
            glowContext.fill(
                Ellipse().path(in: glowRect),
                with: .color(palette.color.opacity(glowOpacity))
            )

            let shapeRect = CGRect(x: center.x - starSize / 2, y: center.y - starSize / 2, width: starSize, height: starSize)
            context.fill(
                starPath(in: shapeRect),
                with: .radialGradient(
                    Gradient(colors: [.white, palette.color.opacity(0.84)]),
                    center: center,
                    startRadius: 0,
                    endRadius: starSize / 2
                )
            )
        }
    }

    private func palette(for index: Int, base: StarPalette) -> StarPalette {
        let delta = Double((index % 5) - 2) * 0.03
        let red = min(1.0, max(0.0, base.rgb.red + delta))
        let green = min(1.0, max(0.0, base.rgb.green + delta))
        let blue = min(1.0, max(0.0, base.rgb.blue + delta))
        return StarPalette(color: Color(red: red, green: green, blue: blue), rgb: (red, green, blue))
    }

    private func basePalette(for constellation: Constellation) -> StarPalette {
        let palette: [StarPalette] = [
            StarPalette(color: Color(red: 1.0, green: 0.45, blue: 0.4), rgb: (1.0, 0.45, 0.4)),
            StarPalette(color: Color(red: 0.49, green: 0.78, blue: 1.0), rgb: (0.49, 0.78, 1.0)),
            StarPalette(color: Color(red: 0.45, green: 0.95, blue: 0.78), rgb: (0.45, 0.95, 0.78)),
            StarPalette(color: Color(red: 0.98, green: 0.84, blue: 0.46), rgb: (0.98, 0.84, 0.46)),
            StarPalette(color: Color(red: 0.84, green: 0.62, blue: 1.0), rgb: (0.84, 0.62, 1.0)),
            StarPalette(color: Color(red: 1.0, green: 0.62, blue: 0.78), rgb: (1.0, 0.62, 0.78)),
            StarPalette(color: Color(red: 0.62, green: 1.0, blue: 0.96), rgb: (0.62, 1.0, 0.96))
        ]
        let key = constellation.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[key % palette.count]
    }

    private func starPath(in rect: CGRect) -> Path {
        switch starStyle {
        case .realistic:
            return Ellipse().path(in: rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1))
        case .fourPoint:
            return fourPointStarPath(in: rect)
        case .fivePoint:
            return fivePointStarPath(in: rect)
        case .eightPoint:
            return eightPointStarPath(in: rect)
        }
    }

    private func fourPointStarPath(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfWidth = rect.width / 2
        let halfHeight = rect.height / 2
        let innerX = halfWidth * 0.35
        let innerY = halfHeight * 0.35

        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - halfHeight))
        path.addQuadCurve(to: CGPoint(x: center.x + halfWidth, y: center.y), control: CGPoint(x: center.x + innerX, y: center.y - innerY))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + halfHeight), control: CGPoint(x: center.x + innerX, y: center.y + innerY))
        path.addQuadCurve(to: CGPoint(x: center.x - halfWidth, y: center.y), control: CGPoint(x: center.x - innerX, y: center.y + innerY))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - halfHeight), control: CGPoint(x: center.x - innerX, y: center.y - innerY))
        return path
    }

    private func fivePointStarPath(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.42

        var path = Path()
        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = (.pi * 2 / 10) * CGFloat(index) - .pi / 2
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                let previous = path.currentPoint ?? point
                let control = CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2)
                path.addQuadCurve(to: point, control: control)
            }
        }
        path.closeSubpath()
        return path
    }

    private func eightPointStarPath(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.25

        var path = Path()
        for index in 0..<16 {
            var radius = innerRadius
            if index.isMultiple(of: 2) {
                radius = index.isMultiple(of: 4) ? outerRadius : outerRadius * 0.6
            }
            let angle = (.pi * 2 / 16) * CGFloat(index) - .pi / 2
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
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

private struct StarPalette {
    let color: Color
    let rgb: (red: Double, green: Double, blue: Double)
}
