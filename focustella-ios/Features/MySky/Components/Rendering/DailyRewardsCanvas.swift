import SwiftUI

struct DailyRewardsCanvas: View {
    let stars: [DailyStarItem]
    let coordinateMapper: MySkyCoordinateMapper
    let camera: MySkyCameraState
    let reduceMotion: Bool
    let isInteracting: Bool
    let animationTime: TimeInterval?

    private let baseColor = Color(red: 1.0, green: 0.9, blue: 0.6)

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: !isInteracting) { context, _ in
            let time = animationTime ?? 0
            let drawRect = CGRect(origin: .zero, size: coordinateMapper.canvasSize).insetBy(dx: -40, dy: -40)

            for star in stars {
                let point = coordinateMapper.screenPoint(fromSky: star.position, camera: camera)
                guard drawRect.contains(point) else { continue }
                drawStar(
                    at: point,
                    in: &context,
                    time: time,
                    phase: Double(star.position.x * 31 + star.position.y * 17)
                )
            }
        }
        .frame(width: coordinateMapper.canvasSize.width, height: coordinateMapper.canvasSize.height)
        .allowsHitTesting(false)
    }

    private func drawStar(
        at point: CGPoint,
        in context: inout GraphicsContext,
        time: TimeInterval,
        phase: Double
    ) {
        let pulse = reduceMotion ? 0.55 : (sin((time + phase) * 1.45) + 1) / 2
        let glowOpacity = isInteracting ? 0.18 : (0.24 + 0.18 * pulse)
        let starSize: CGFloat = isInteracting ? 13.6 : (14.5 + CGFloat(pulse) * 1.8)
        let glowRadius: CGFloat = isInteracting ? 13 : (15.5 + CGFloat(pulse) * 2.8)

        if !isInteracting {
            var glowContext = context
            glowContext.addFilter(.blur(radius: 2.4))
            let glowRect = CGRect(
                x: point.x - glowRadius,
                y: point.y - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            )
            glowContext.fill(
                Ellipse().path(in: glowRect),
                with: .color(baseColor.opacity(glowOpacity))
            )
        }

        let starRect = CGRect(
            x: point.x - starSize / 2,
            y: point.y - starSize / 2,
            width: starSize,
            height: starSize
        )
        context.fill(
            rewardStarPath(in: starRect, innerRatio: 0.35),
            with: .radialGradient(
                Gradient(colors: [.white, baseColor]),
                center: point,
                startRadius: 0,
                endRadius: starSize / 2
            )
        )
    }

    private func rewardStarPath(in rect: CGRect, innerRatio: CGFloat) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let w = rect.width / 2
        let h = rect.height / 2
        let ix = w * innerRatio
        let iy = h * innerRatio
        var path = Path()

        path.move(to: CGPoint(x: center.x, y: center.y - h))
        path.addQuadCurve(
            to: CGPoint(x: center.x + w, y: center.y),
            control: CGPoint(x: center.x + ix, y: center.y - iy)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y + h),
            control: CGPoint(x: center.x + ix, y: center.y + iy)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x - w, y: center.y),
            control: CGPoint(x: center.x - ix, y: center.y + iy)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y - h),
            control: CGPoint(x: center.x - ix, y: center.y - iy)
        )

        return path
    }
}
