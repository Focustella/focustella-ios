import SwiftUI

struct ConstellationRenderer: View {
    let constellation: Constellation
    let discoveredStarCount: Int
    let showEdges: Bool
    let edgeProgress: CGFloat
    let reduceMotion: Bool
    let highPerformanceMode: Bool
    var sparklingIndices: Set<Int> = []
    var edgeRevealOrder: [Int]? = nil
    var visibleEdgeIndices: Set<Int>? = nil
    var edgeVisibilityOverrides: [Int: CGFloat]? = nil

    var body: some View {
        let shouldAnimate = highPerformanceMode && !reduceMotion
        TimelineView(.periodic(from: .now, by: shouldAnimate ? 1.0 / 8.0 : 1.2)) { context in
            GeometryReader { proxy in
                let size = proxy.size
                let time = context.date.timeIntervalSinceReferenceDate
                let pointsById = Dictionary(uniqueKeysWithValues: constellation.stars.map { ($0.id, worldPoint(fromNormalized: CGPoint(x: $0.x, y: $0.y), size: size)) })
                let constellationBase = basePaletteForConstellation()

                ZStack {
                    if showEdges {
                        let edgeCount = max(1, constellation.edges.count)
                        let reveal = CGFloat(edgeCount) * max(0, min(1, edgeProgress))
                        let edgePulse = shouldAnimate ? (sin(time * 1.0) + 1) / 2 : 0.35
                        let edgeOpacity = shouldAnimate ? (0.15 + 0.14 * edgePulse) : 0.18
                        let edgeGlow = shouldAnimate ? (1.7 + CGFloat(edgePulse) * 1.9) : 1.6
                        let edgeBaseColor = constellationBase.color
                        let orderedIndices = edgeRevealOrder ?? Array(constellation.edges.indices)

                        ForEach(Array(orderedIndices.enumerated()), id: \.offset) { order, edgeIndex in
                            let isVisible = visibleEdgeIndices?.contains(edgeIndex) ?? true
                            if constellation.edges.indices.contains(edgeIndex), isVisible {
                                let local = min(1, max(0, reveal - CGFloat(order)))
                                if local > 0 {
                                    let eased = local * local * (3 - 2 * local)
                                    let visibility = edgeVisibilityOverrides?[edgeIndex] ?? 1
                                    if visibility > 0 {
                                        let edge = constellation.edges[edgeIndex]
                                        if let from = pointsById[edge.from], let to = pointsById[edge.to] {
                                            Path { path in
                                                path.move(to: from)
                                                path.addLine(to: to)
                                            }
                                            .stroke(
                                                edgeBaseColor.opacity(edgeOpacity * eased * visibility),
                                                style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                                            )
                                            .shadow(
                                                color: edgeBaseColor.opacity(edgeOpacity * eased * visibility * 0.85),
                                                radius: edgeGlow * eased
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ForEach(Array(constellation.stars.enumerated()), id: \.element.id) { index, star in
                        let discovered = index < discoveredStarCount
                        let sparkle = sparklingIndices.contains(index)
                        let position = worldPoint(fromNormalized: CGPoint(x: star.x, y: star.y), size: size)
                        let phaseOffset = Double(star.x * 30 + star.y * 15)
                        let palette = starPalette(for: index, base: constellationBase)

                        if discovered || sparkle {
                            TwinklingStarNode(
                                position: position,
                                size: 11,
                                phaseOffset: phaseOffset,
                                color: palette.color,
                                baseRGB: palette.rgb,
                                time: time,
                                reduceMotion: reduceMotion,
                                boost: sparkle,
                                isAnimated: shouldAnimate,
                                hasFlare: shouldAnimate && (sparkle || index.isMultiple(of: 6))
                            )
                            .opacity(1.0)
                            .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func worldPoint(fromNormalized point: CGPoint, size: CGSize) -> CGPoint {
        let side = min(size.width, size.height)
        let origin = CGPoint(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2
        )
        return CGPoint(
            x: origin.x + point.x * side,
            y: origin.y + point.y * side
        )
    }

    private func starPalette(for index: Int, base: StarPalette) -> StarPalette {
        let delta = Double((index % 5) - 2) * 0.03
        let r = min(1.0, max(0.0, base.rgb.red + delta))
        let g = min(1.0, max(0.0, base.rgb.green + delta))
        let b = min(1.0, max(0.0, base.rgb.blue + delta))
        return StarPalette(color: Color(red: r, green: g, blue: b), rgb: (r, g, b))
    }

    private func basePaletteForConstellation() -> StarPalette {
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
}

private struct TwinklingStarNode: View {
    let position: CGPoint
    let size: CGFloat
    let phaseOffset: Double
    let color: Color
    let baseRGB: (red: Double, green: Double, blue: Double)
    let time: TimeInterval
    let reduceMotion: Bool
    let boost: Bool
    let isAnimated: Bool
    let hasFlare: Bool

    var body: some View {
        let t = time + phaseOffset
        let pulse = (!isAnimated || reduceMotion) ? 0.5 : (sin(t * 1.6) + 1) / 2
        let flicker = (!isAnimated || reduceMotion) ? 0.5 : (sin(t * 0.7 + phaseOffset * 2.0) + 1) / 2

        let opacity = (0.72 + 0.28 * pulse) * (boost ? 1.08 : 1.0)
        let glow = (2.0 + 6.5 * pulse) * (boost ? 1.12 : 1.0)
        let glowOpacity = min(1.0, (0.45 + 0.55 * flicker) * (boost ? 1.12 : 1.0))
        let glowColor = Color(
            red: min(1.0, baseRGB.red + 0.04),
            green: min(1.0, baseRGB.green + 0.04),
            blue: min(1.0, baseRGB.blue + 0.04),
            opacity: glowOpacity
        )
        let flareOpacity = reduceMotion ? 0.14 : (0.18 + 0.2 * flicker) * (boost ? 1.12 : 1.0)
        let flareLength = size * (boost ? 2.8 : 2.2) * (0.9 + pulse * 0.3)

        ZStack {
            // Diffraction-like spikes for bright stars.
            if hasFlare {
                StarFlare(
                    length: flareLength,
                    thickness: max(0.4, size * 0.055),
                    color: glowColor.opacity(flareOpacity)
                )
                .rotationEffect(.degrees(0))

                StarFlare(
                    length: flareLength * 0.7,
                    thickness: max(0.3, size * 0.04),
                    color: glowColor.opacity(flareOpacity * 0.6)
                )
                .rotationEffect(.degrees(45))
            }

            TwinkleStarShape(points: 4, innerRatio: 0.45)
                .fill(color)
                .frame(width: size, height: size)
        }
        .shadow(color: glowColor, radius: glow)
        .opacity(opacity)
        .position(position)
    }
}

private struct StarPalette {
    let color: Color
    let rgb: (red: Double, green: Double, blue: Double)
}

private struct TwinkleStarShape: Shape {
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

private struct StarFlare: View {
    let length: CGFloat
    let thickness: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, color, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: length, height: thickness)
                .blur(radius: thickness * 0.5)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, color, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: thickness, height: length)
                .blur(radius: thickness * 0.5)
        }
        .allowsHitTesting(false)
    }
}
