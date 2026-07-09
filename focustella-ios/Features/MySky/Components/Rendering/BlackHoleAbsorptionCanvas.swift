import SwiftUI

struct BlackHoleAbsorptionCanvas: View {
    let center: CGPoint
    let phase: MySkyBlackHoleCoordinator.Phase
    let absorption: MySkyBlackHoleCoordinator.AbsorptionParameters

    private var isActive: Bool {
        switch phase {
        case .stage4, .stage5, .stage6, .stage7Spawning, .stage7Absorbing, .stage7AwaitingInput, .stage8Collapsing, .blackout:
            return true
        default:
            return false
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isActive)) { _ in
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                guard isActive else { return }

                let rect = CGRect(origin: .zero, size: size)
                let centerScreen = CGPoint(x: center.x * size.width, y: center.y * size.height)

                drawEdgeVignette(in: &context, rect: rect, center: centerScreen)
                drawCenterDarkening(in: &context, rect: rect, center: centerScreen, size: size)
                drawBlackout(in: &context, rect: rect)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawEdgeVignette(in context: inout GraphicsContext, rect: CGRect, center: CGPoint) {
        let vignetteAmount = clamp(absorption.vignette)
        guard vignetteAmount > 0.001 else { return }

        let maxRadius = max(rect.width, rect.height) * 0.92
        let startRadius = max(rect.width, rect.height) * 0.28

        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                Color.clear,
                Color.black.opacity(0.18 * vignetteAmount),
                Color.black.opacity(0.66 * vignetteAmount)
            ]),
            center: center,
            startRadius: startRadius,
            endRadius: maxRadius
        )

        context.fill(Path(rect), with: shading)
    }

    private func drawCenterDarkening(
        in context: inout GraphicsContext,
        rect: CGRect,
        center: CGPoint,
        size: CGSize
    ) {
        let centerDarkening = clamp(absorption.centerDarkening)
        guard centerDarkening > 0.001 else { return }

        let endRadius = min(size.width, size.height) * (0.20 + 0.18 * (1 - clamp(absorption.collapse)))
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                Color.black.opacity(0.80 * centerDarkening),
                Color.black.opacity(0.42 * centerDarkening),
                Color.clear
            ]),
            center: center,
            startRadius: 0,
            endRadius: endRadius
        )
        context.fill(Path(rect), with: shading)
    }

    private func drawBlackout(in context: inout GraphicsContext, rect: CGRect) {
        let blackout = clamp(absorption.blackout)
        guard blackout > 0.001 else { return }
        context.fill(Path(rect), with: .color(Color.black.opacity(blackout)))
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
