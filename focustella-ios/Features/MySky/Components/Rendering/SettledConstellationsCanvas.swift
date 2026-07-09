import SwiftUI

struct SettledConstellationsCanvas: View {
    struct Item: Identifiable {
        let metadata: MySkyConstellationRenderMetadata
        let discoveredStarCount: Int
        let visibleEdgeIndices: Set<Int>
        let edgeVisibilityOverrides: [Int: CGFloat]

        var id: UUID { metadata.id }
    }

    let items: [Item]
    let coordinateMapper: MySkyCoordinateMapper
    let camera: MySkyCameraState
    let starStyle: StarAppearanceStyle
    let reduceMotion: Bool
    let highPerformanceMode: Bool
    let isInteracting: Bool
    let animationTime: TimeInterval?

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: !isInteracting) { context, _ in
            let shouldAnimate = highPerformanceMode && !reduceMotion && !isInteracting
            // Keep drag rendering policy identical to high-performance mode across all modes.
            let useLightweightShading = isInteracting
            let time = animationTime ?? 0
            let viewportRect = CGRect(origin: .zero, size: coordinateMapper.canvasSize)
            let detailedRenderRect = viewportRect.insetBy(dx: -48, dy: -48)
            let simplifiedRenderRect = viewportRect.insetBy(dx: -220, dy: -220)

            for item in items {
                drawConstellation(
                    item,
                    in: &context,
                    time: time,
                    shouldAnimate: shouldAnimate,
                    useLightweightShading: useLightweightShading,
                    detailedRenderRect: detailedRenderRect,
                    simplifiedRenderRect: simplifiedRenderRect
                )
            }
        }
        .frame(
            width: coordinateMapper.canvasSize.width,
            height: coordinateMapper.canvasSize.height
        )
        .compositingGroup()
        .allowsHitTesting(false)
    }

    private func drawConstellation(
        _ item: Item,
        in context: inout GraphicsContext,
        time: TimeInterval,
        shouldAnimate: Bool,
        useLightweightShading: Bool,
        detailedRenderRect: CGRect,
        simplifiedRenderRect: CGRect
    ) {
        let metadata = item.metadata
        let screenPoints = metadata.starSkyPoints.map { coordinateMapper.screenPoint(fromSky: $0, camera: camera) }
        let basePalette = basePalette(seed: metadata.paletteSeed)
        let discoveredCount = min(item.discoveredStarCount, screenPoints.count)
        let edgePulse = shouldAnimate ? (sin(time * 0.85) + 1) / 2 : 0.35
        let edgeOpacity = shouldAnimate ? (0.11 + 0.08 * edgePulse) : 0.12

        for edgeIndex in item.visibleEdgeIndices {
            guard metadata.edgeIndexPairs.indices.contains(edgeIndex) else { continue }
            let visibility = max(0, min(1, item.edgeVisibilityOverrides[edgeIndex] ?? 1))
            guard visibility > 0 else { continue }

            guard let edge = metadata.edgeIndexPairs[edgeIndex],
                  screenPoints.indices.contains(edge.from),
                  screenPoints.indices.contains(edge.to) else { continue }
            let from = screenPoints[edge.from]
            let to = screenPoints[edge.to]
            let fromTier = renderTier(at: from, detailedRect: detailedRenderRect, simplifiedRect: simplifiedRenderRect)
            let toTier = renderTier(at: to, detailedRect: detailedRenderRect, simplifiedRect: simplifiedRenderRect)
            if fromTier == .culled && toTier == .culled { continue }

            let edgeBounds = CGRect(
                x: min(from.x, to.x),
                y: min(from.y, to.y),
                width: max(abs(to.x - from.x), 1),
                height: max(abs(to.y - from.y), 1)
            ).insetBy(dx: -1, dy: -1)
            guard simplifiedRenderRect.intersects(edgeBounds) else { continue }

            var path = Path()
            path.move(to: from)
            path.addLine(to: to)

            let simplifiedEdge = fromTier != .detailed || toTier != .detailed
            if useLightweightShading || simplifiedEdge {
                context.stroke(
                    path,
                    with: .color(basePalette.color.opacity((simplifiedEdge ? 0.08 : 0.12) * Double(visibility))),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                )
            } else {
                var glowContext = context
                glowContext.addFilter(.shadow(color: basePalette.color.opacity(edgeOpacity * Double(visibility) * 0.5), radius: shouldAnimate ? 2.6 : 1.8, x: 0, y: 0))
                glowContext.stroke(
                    path,
                    with: .color(basePalette.color.opacity(edgeOpacity * Double(visibility))),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                )
            }
        }

        for index in 0..<discoveredCount {
            let center = screenPoints[index]
            let tier = renderTier(at: center, detailedRect: detailedRenderRect, simplifiedRect: simplifiedRenderRect)
            if tier == .culled { continue }

            let skyPoint = metadata.starSkyPoints[index]
            let phaseOffset = Double(skyPoint.x * 30 + skyPoint.y * 15)
            let pulse = shouldAnimate ? (sin((time + phaseOffset) * 1.2) + 1) / 2 : 0.5
            let flicker = shouldAnimate ? (sin((time + phaseOffset) * 0.55 + phaseOffset * 1.6) + 1) / 2 : 0.5
            let palette = palette(for: index, base: basePalette)
            let glowOpacity = shouldAnimate ? (0.24 + 0.16 * flicker) : 0.24
            let starSize: CGFloat = 8.2 + (shouldAnimate ? CGFloat(pulse) * 0.9 : 0)
            let simplifiedStar = tier == .simplified

            if useLightweightShading || simplifiedStar {
                let compactSize = simplifiedStar ? 5.0 : max(6.8, starSize * 0.9)
                let compactRect = CGRect(
                    x: center.x - compactSize / 2,
                    y: center.y - compactSize / 2,
                    width: compactSize,
                    height: compactSize
                )
                context.fill(
                    starPath(in: compactRect),
                    with: .color(palette.color.opacity(simplifiedStar ? 0.62 : 0.86))
                )
            } else {
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
    }

    private func renderTier(at point: CGPoint, detailedRect: CGRect, simplifiedRect: CGRect) -> RenderTier {
        if detailedRect.contains(point) { return .detailed }
        if simplifiedRect.contains(point) { return .simplified }
        return .culled
    }

    private func palette(for index: Int, base: StarPalette) -> StarPalette {
        let delta = Double((index % 5) - 2) * 0.03
        let red = min(1.0, max(0.0, base.rgb.red + delta))
        let green = min(1.0, max(0.0, base.rgb.green + delta))
        let blue = min(1.0, max(0.0, base.rgb.blue + delta))
        return StarPalette(color: Color(red: red, green: green, blue: blue), rgb: (red, green, blue))
    }

    private func basePalette(seed: Int) -> StarPalette {
        let palette: [StarPalette] = [
            StarPalette(color: Color(red: 1.0, green: 0.45, blue: 0.4), rgb: (1.0, 0.45, 0.4)),
            StarPalette(color: Color(red: 0.49, green: 0.78, blue: 1.0), rgb: (0.49, 0.78, 1.0)),
            StarPalette(color: Color(red: 0.45, green: 0.95, blue: 0.78), rgb: (0.45, 0.95, 0.78)),
            StarPalette(color: Color(red: 0.98, green: 0.84, blue: 0.46), rgb: (0.98, 0.84, 0.46)),
            StarPalette(color: Color(red: 0.84, green: 0.62, blue: 1.0), rgb: (0.84, 0.62, 1.0)),
            StarPalette(color: Color(red: 1.0, green: 0.62, blue: 0.78), rgb: (1.0, 0.62, 0.78)),
            StarPalette(color: Color(red: 0.62, green: 1.0, blue: 0.96), rgb: (0.62, 1.0, 0.96))
        ]
        return palette[seed % palette.count]
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

private enum RenderTier {
    case detailed
    case simplified
    case culled
}
