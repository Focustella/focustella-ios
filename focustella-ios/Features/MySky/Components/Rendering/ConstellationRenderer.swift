import SwiftUI

struct ConstellationRenderer: View {
    let constellation: Constellation
    let coordinateMapper: MySkyCoordinateMapper
    var camera: MySkyCameraState = .default
    let discoveredStarCount: Int
    let showEdges: Bool
    let edgeProgress: CGFloat
    let reduceMotion: Bool
    let highPerformanceMode: Bool
    var renderMetadata: MySkyConstellationRenderMetadata? = nil
    var discoveredStarIndices: Set<Int>? = nil
    var sparklingIndices: Set<Int> = []
    var edgeRevealOrder: [Int]? = nil
    var visibleEdgeIndices: Set<Int>? = nil
    var edgeVisibilityOverrides: [Int: CGFloat]? = nil
    var starStyle: StarAppearanceStyle = .realistic
    var activeBirthEffect: StarBirthEffectState? = nil
    var animationTime: TimeInterval? = nil
    var userSeed: Int = 0

    var body: some View {
        let shouldAnimate = highPerformanceMode && !reduceMotion
        let needsTimeline = shouldAnimate || activeBirthEffect != nil

        Group {
            if let animationTime {
                content(time: animationTime, shouldAnimate: shouldAnimate)
            } else if needsTimeline {
                TimelineView(.periodic(from: .now, by: shouldAnimate ? 1.0 / 10.0 : 1.0 / 8.0)) { context in
                    content(time: context.date.timeIntervalSinceReferenceDate, shouldAnimate: shouldAnimate)
                }
            } else {
                content(time: 0, shouldAnimate: false)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func content(time: TimeInterval, shouldAnimate: Bool) -> some View {
        let mapper = coordinateMapper
        let metadata = renderMetadata
        let screenPoints = (metadata?.starSkyPoints ?? constellation.stars.map { CGPoint(x: $0.x, y: $0.y) })
            .map { mapper.screenPoint(fromSky: $0, camera: camera) }
        let constellationBase = basePaletteForConstellation()
        let birthSegments = activeBirthEffect?.connectionPairs.compactMap { pair -> StarBirthSegment? in
            let fromIndex = metadata?.starIndex(for: pair.fromStarId) ?? constellation.stars.firstIndex { $0.id == pair.fromStarId }
            let toIndex = metadata?.starIndex(for: pair.toStarId) ?? constellation.stars.firstIndex { $0.id == pair.toStarId }
            guard
                let fromIndex,
                let toIndex,
                screenPoints.indices.contains(fromIndex),
                screenPoints.indices.contains(toIndex)
            else { return nil }
            let from = screenPoints[fromIndex]
            let to = screenPoints[toIndex]
            return StarBirthSegment(from: from, to: to)
        } ?? []

        ZStack {
            if let activeBirthEffect, !birthSegments.isEmpty {
                RendererBirthConnectionsView(
                    connectionSegments: birthSegments,
                    reduceMotion: reduceMotion
                )
                .id("connections-\(activeBirthEffect.token)")
            }

            if showEdges {
                let edgeCount = max(1, constellation.edges.count)
                let reveal = CGFloat(edgeCount) * max(0, min(1, edgeProgress))
                let edgePulse = shouldAnimate ? (sin(time * 1.0) + 1) / 2 : 0.35
                let edgeOpacity = shouldAnimate ? (0.15 + 0.14 * edgePulse) : 0.14
                let edgeGlow = shouldAnimate ? (1.7 + CGFloat(edgePulse) * 1.9) : 0
                let edgeBaseColor = constellationBase.color
                let orderedIndices = edgeRevealOrder ?? Array(constellation.edges.indices)
                let edgeIndexPairs = metadata?.edgeIndexPairs

                ForEach(Array(orderedIndices.enumerated()), id: \.offset) { order, edgeIndex in
                    let isVisible = visibleEdgeIndices?.contains(edgeIndex) ?? true
                    if constellation.edges.indices.contains(edgeIndex), isVisible {
                        let local = min(1, max(0, reveal - CGFloat(order)))
                        if local > 0 {
                            let eased = local * local * (3 - 2 * local)
                            let visibility = edgeVisibilityOverrides?[edgeIndex] ?? 1
                            if visibility > 0 {
                                if let pair = edgePair(
                                    at: edgeIndex,
                                    metadataPairs: edgeIndexPairs
                                ),
                                   screenPoints.indices.contains(pair.from),
                                   screenPoints.indices.contains(pair.to) {
                                    let from = screenPoints[pair.from]
                                    let to = screenPoints[pair.to]
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
                let discovered = discoveredStarIndices?.contains(index) ?? (index < discoveredStarCount)
                let sparkle = sparklingIndices.contains(index)
                let isBirthStar = activeBirthEffect?.starId == star.id
                let position = screenPoints.indices.contains(index) ? screenPoints[index] : mapper.screenPoint(
                    fromSky: CGPoint(x: star.x, y: star.y),
                    camera: camera
                )
                let phaseOffset = Double(star.x * 30 + star.y * 15)
                let palette = starPalette(for: index, base: constellationBase)
                let flareStride = constellation.starCount > 4 ? 12 : 6
                let starSize = 11 * MySkyStarSizeScale.scale(
                    userSeed: userSeed,
                    constellationId: constellation.id,
                    starId: star.id
                )

                if discovered || sparkle || isBirthStar {
                    ZStack {
                        if isBirthStar, let activeBirthEffect {
                            RendererRippleBurstView(reduceMotion: reduceMotion)
                                .id("ripple-\(activeBirthEffect.token)")
                            RendererStarBirthIgnitionView(reduceMotion: reduceMotion)
                                .id("ignition-\(activeBirthEffect.token)")
                        }

                        TwinklingStarNode(
                            position: nil,
                            size: starSize,
                            phaseOffset: phaseOffset,
                            color: palette.color,
                            baseRGB: palette.rgb,
                            time: time,
                            reduceMotion: reduceMotion,
                            boost: sparkle || isBirthStar,
                            isAnimated: shouldAnimate,
                            hasFlare: shouldAnimate && (sparkle || isBirthStar || index.isMultiple(of: flareStride)),
                            currentStyle: starStyle
                        )
                        .opacity((discovered || sparkle) ? 1.0 : 0.001)
                    }
                    .position(position)
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(width: mapper.canvasSize.width, height: mapper.canvasSize.height)
    }

    private func edgePair(
        at index: Int,
        metadataPairs: [(from: Int, to: Int)?]?
    ) -> (from: Int, to: Int)? {
        if let pair = metadataPairs?[safe: index] ?? nil {
            return pair
        }

        guard constellation.edges.indices.contains(index) else { return nil }
        let edge = constellation.edges[index]
        guard
            let from = constellation.stars.firstIndex(where: { $0.id == edge.from }),
            let to = constellation.stars.firstIndex(where: { $0.id == edge.to })
        else { return nil }
        return (from, to)
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

private struct RendererRippleBurstView: View {
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0.0
    private let coreColor = Color(white: 0.95)
    private let glowColor = Color(red: 0.78, green: 0.92, blue: 1.0)

    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle()
                    .stroke(coreColor.opacity(0.7 * (1 - progress)), lineWidth: 15 * (1 - progress * 0.5))
                    .frame(width: 20 + (progress * 100), height: 20 + (progress * 100))
                    .blur(radius: 10)
                    .padding(20)
                Circle()
                    .stroke(glowColor.opacity(0.5 * (1 - progress)), lineWidth: 25 * (1 - progress * 0.5))
                    .frame(width: 10 + (progress * 140), height: 10 + (progress * 140))
                    .blur(radius: 20)
                    .padding(30)
                Circle()
                    .stroke(glowColor.opacity(0.3 * (1 - progress)), lineWidth: 40 * (1 - progress * 0.8))
                    .frame(width: 5 + (progress * 180), height: 5 + (progress * 180))
                    .blur(radius: 40)
                    .padding(50)
            }
        }
        .frame(width: 300, height: 300)
        .onAppear {
            withAnimation(.easeOut(duration: 2.0)) {
                progress = 1.0
            }
        }
    }
}

private struct RendererBirthConnectionsView: View {
    let connectionSegments: [StarBirthSegment]
    let reduceMotion: Bool
    @State private var connectionPulse: CGFloat = 0
    private let style = StarBirthEffectStyle.minimal

    var body: some View {
        ZStack {
            ForEach(Array(connectionSegments.enumerated()), id: \.offset) { index, segment in
                let itemDelay = Double(index) * 0.03
                let local = max(0, min(1, connectionPulse - CGFloat(itemDelay / max(0.001, style.connectionResponseDuration))))
                let eased = local * local * (3 - 2 * local)
                Path { path in
                    path.move(to: segment.from)
                    path.addLine(to: segment.to)
                }
                .stroke(
                    Color.white.opacity(0.22 * eased),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color.white.opacity(0.18 * eased), radius: 2.4 * eased)
            }
        }
        .onAppear {
            if reduceMotion {
                connectionPulse = 1
            } else {
                withAnimation(.easeOut(duration: style.connectionResponseDuration).delay(style.preludeDuration + style.condenseDuration + 0.1)) {
                    connectionPulse = 1
                }
            }
        }
    }
}

private struct RendererStarBirthIgnitionView: View {
    let reduceMotion: Bool
    private let style = StarBirthEffectStyle.minimal
    @State private var prelude: CGFloat = 0
    @State private var condense: CGFloat = 0
    @State private var birth: CGFloat = 0
    @State private var settle: CGFloat = 0
    @State private var masterOpacity: CGFloat = 1

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.16 * prelude))
                .frame(width: 72, height: 72)
                .blur(radius: 20 * prelude)

            ForEach(0..<style.particleCount, id: \.self) { index in
                let angle = (Double(index) / Double(style.particleCount)) * .pi * 2
                let swirl = reduceMotion ? 0 : Double(condense) * 0.9
                let radius = (28 - (24 * condense))
                let x = cos(angle + swirl) * radius
                let y = sin(angle + swirl) * radius

                Circle()
                    .fill(Color.white.opacity(0.18 + 0.42 * (1 - condense)))
                    .frame(width: reduceMotion ? 2.8 : 3.6, height: reduceMotion ? 2.8 : 3.6)
                    .blur(radius: reduceMotion ? 0.5 : 1.2)
                    .offset(x: x, y: y)
            }

            Circle()
                .fill(Color.white.opacity(0.22 + 0.62 * condense))
                .frame(width: 12, height: 12)
                .scaleEffect(0.6 + 0.5 * birth)
                .blur(radius: 1.6 + (4.0 * condense))

            Group {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.75 * birth), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 32, height: 1)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.75 * birth), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1, height: 32)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.45 * birth), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 22, height: 1)
                    .rotationEffect(.degrees(45))
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.45 * birth), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 22, height: 1)
                    .rotationEffect(.degrees(-45))
            }
            .blur(radius: 0.6)

            Circle()
                .stroke(Color.white.opacity(0.22 * birth), lineWidth: 1.2)
                .frame(width: style.ringStartRadius, height: style.ringStartRadius)
                .scaleEffect(1 + (style.ringEndRadius / max(1, style.ringStartRadius) * birth))
                .opacity(1 - birth)

            ForEach(0..<3, id: \.self) { index in
                let baseAngle = (Double(index) / 3.0) * .pi * 2
                let drift = CGFloat(12 + (index * 4)) * settle
                Circle()
                    .fill(Color.white.opacity(0.24 * (1 - settle)))
                    .frame(width: 2.6, height: 2.6)
                    .offset(
                        x: cos(baseAngle) * drift,
                        y: sin(baseAngle) * drift
                    )
                    .blur(radius: 0.8)
            }
        }
        .scaleEffect(style.effectScale, anchor: .center)
        .opacity(masterOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: style.preludeDuration)) {
                prelude = 1
            }
            withAnimation(.easeInOut(duration: style.condenseDuration).delay(style.preludeDuration * 0.5)) {
                condense = 1
            }
            withAnimation(.interpolatingSpring(stiffness: 210, damping: 20).delay(style.preludeDuration + style.condenseDuration * 0.55)) {
                birth = 1
            }
            withAnimation(.easeOut(duration: style.settleDuration).delay(style.preludeDuration + style.condenseDuration + style.birthDuration * 0.35)) {
                settle = 1
            }
            let fadeDelay = style.preludeDuration + style.condenseDuration + style.birthDuration + style.settleDuration + style.holdDuration
            withAnimation(.easeOut(duration: style.fadeOutDuration).delay(fadeDelay)) {
                masterOpacity = 0
            }
        }
    }
}

private struct TwinklingStarNode: View {
    let position: CGPoint?
    let size: CGFloat
    let phaseOffset: Double
    let color: Color
    let baseRGB: (red: Double, green: Double, blue: Double)
    let time: TimeInterval
    let reduceMotion: Bool
    let boost: Bool
    let isAnimated: Bool
    let hasFlare: Bool
    let currentStyle: StarAppearanceStyle

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

        let content = ZStack {
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
            starShapeView(size: size, color: color)
        }
        .shadow(color: glowColor, radius: glow)
        .opacity(opacity)

        if let position {
            content.position(position)
        } else {
            content
        }
    }
    
    @ViewBuilder
        private func starShapeView(size: CGFloat, color: Color) -> some View {
            let gradient = RadialGradient(colors: [.white, color], center: .center, startRadius: 0, endRadius: size / 2)
            
            switch currentStyle {
            case .realistic:
                Circle()
                    .fill(RadialGradient(colors: [.white, color.opacity(0.8)], center: .center, startRadius: 0, endRadius: size / 2))
                    .frame(width: size * 0.8, height: size * 0.8)
                    .blur(radius: 1.0)
            case .fourPoint:
                FourPointStarShape()
                    .fill(gradient)
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-5))
            case .fivePoint:
                FivePointStarShape()
                    .fill(gradient)
                    .frame(width: size, height: size)
            case .eightPoint:
                EightPointStarShape()
                    .fill(gradient)
                    .frame(width: size, height: size)
            }
        }
    
    // 🔥 2. 4각 별 Shape
    private struct FourPointStarShape: Shape {
        var innerRatio: CGFloat = 0.35
        func path(in rect: CGRect) -> Path {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let w = rect.width / 2, h = rect.height / 2
            let ix = w * innerRatio, iy = h * innerRatio
            var p = Path()
            p.move(to: CGPoint(x: center.x, y: center.y - h))
            p.addQuadCurve(to: CGPoint(x: center.x + w, y: center.y), control: CGPoint(x: center.x + ix, y: center.y - iy))
            p.addQuadCurve(to: CGPoint(x: center.x, y: center.y + h), control: CGPoint(x: center.x + ix, y: center.y + iy))
            p.addQuadCurve(to: CGPoint(x: center.x - w, y: center.y), control: CGPoint(x: center.x - ix, y: center.y + iy))
            p.addQuadCurve(to: CGPoint(x: center.x, y: center.y - h), control: CGPoint(x: center.x - ix, y: center.y - iy))
            return p
        }
    }

    // 🔥 3. 5각 별 Shape
    private struct FivePointStarShape: Shape {
        func path(in rect: CGRect) -> Path {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerRadius = min(rect.width, rect.height) / 2
            let innerRadius = outerRadius * 0.42
            var p = Path()
            for i in 0..<10 {
                let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
                let angle = (.pi * 2 / 10) * CGFloat(i) - .pi / 2
                let pt = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                if i == 0 { p.move(to: pt) }
                else {
                    let cp = CGPoint(x: (p.currentPoint!.x + pt.x)/2, y: (p.currentPoint!.y + pt.y)/2)
                    p.addQuadCurve(to: pt, control: cp)
                }
            }
            p.closeSubpath()
            return p
        }
    }

    // 🔥 4. 8각 별 Shape
    private struct EightPointStarShape: Shape {
        func path(in rect: CGRect) -> Path {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outer = min(rect.width, rect.height) / 2
            let inner = outer * 0.25
            var p = Path()
            for i in 0..<16 {
                var r = inner
                if i.isMultiple(of: 2) { r = i.isMultiple(of: 4) ? outer : outer * 0.6 }
                let angle = (.pi * 2 / 16) * CGFloat(i) - .pi / 2
                let pt = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            return p
        }
    }

}


private struct StarPalette {
    let color: Color
    let rgb: (red: Double, green: Double, blue: Double)
}

//private struct TwinkleStarShape: Shape {
//    let points: Int
//    let innerRatio: CGFloat
//
//    func path(in rect: CGRect) -> Path {
//        let center = CGPoint(x: rect.midX, y: rect.midY)
//        let outerRadius = min(rect.width, rect.height) / 2
//        let innerRadius = outerRadius * innerRatio
//        let angleStep = .pi * 2 / CGFloat(points * 2)
//
//        var path = Path()
//        for index in 0..<(points * 2) {
//            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
//            let angle = angleStep * CGFloat(index) - .pi / 2
//            let point = CGPoint(
//                x: center.x + cos(angle) * radius,
//                y: center.y + sin(angle) * radius
//            )
//            if index == 0 {
//                path.move(to: point)
//            } else {
//                path.addLine(to: point)
//            }
//        }
//        path.closeSubpath()
//        return path
//    }
//}

//// ✅ 새로운 부드러운 곡선형 별 Shape로 교체
//private struct TwinkleStarShape: Shape {
//    // 호환성을 위해 기존 프로퍼티 이름 유지
//    let points: Int // 4점 별로 가정
//    let innerRatio: CGFloat
//
//    func path(in rect: CGRect) -> Path {
//        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
//        let width = rect.width
//        let height = rect.height
//        
//        let top = CGPoint(x: center.x, y: 0)
//        let bottom = CGPoint(x: center.x, y: height)
//        let left = CGPoint(x: 0, y: center.y)
//        let right = CGPoint(x: width, y: center.y)
//        
//        // innerRatio를 사용하여 안쪽으로 오목하게 들어가는 깊이 조절
//        let innerX = width * innerRatio / 2
//        let innerY = height * innerRatio / 2
//        
//        let innerTopLeft = CGPoint(x: center.x - innerX, y: center.y - innerY)
//        let innerTopRight = CGPoint(x: center.x + innerX, y: center.y - innerY)
//        let innerBottomLeft = CGPoint(x: center.x - innerX, y: center.y + innerY)
//        let innerBottomRight = CGPoint(x: center.x + innerX, y: center.y + innerY)
//
//        var path = Path()
//        path.move(to: top)
//        // 직선 대신 2차 베지어 곡선(QuadCurve)으로 부드럽게 깎아냄
//        path.addQuadCurve(to: right, control: innerTopRight)
//        path.addQuadCurve(to: bottom, control: innerBottomRight)
//        path.addQuadCurve(to: left, control: innerBottomLeft)
//        path.addQuadCurve(to: top, control: innerTopLeft)
//        path.closeSubpath()
//        
//        return path
//    }
//}

// 📂 ConstellationRenderer.swift 맨 하단 덮어쓰기

private struct TwinkleStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.25 // 아주 깊게 파서 뾰족하게
        let points = 8
        let angleStep = .pi * 2 / CGFloat(points * 2)

        var path = Path()
        for index in 0..<(points * 2) {
            var radius: CGFloat = innerRadius
            
            if index.isMultiple(of: 2) {
                // 짝수 인덱스(바깥쪽 점)일 때, 길이를 번갈아가며 다르게 설정
                radius = index.isMultiple(of: 4) ? outerRadius : outerRadius * 0.6
            }
            
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
