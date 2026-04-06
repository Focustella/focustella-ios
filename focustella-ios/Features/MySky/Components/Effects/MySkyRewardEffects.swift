import SwiftUI

struct DailyRewardStarNode: View {
    @State private var isBlinking = false

    var body: some View {
        let size: CGFloat = 16
        let color = Color(red: 1.0, green: 0.9, blue: 0.6)

        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2.5, height: size * 2.5)
                .blur(radius: size * 0.4)
                .opacity(isBlinking ? 1.0 : 0.5)

            RewardStarShape(innerRatio: 0.35)
                .fill(
                    RadialGradient(
                        colors: [.white, color],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isBlinking = true
            }
        }
    }
}

struct RewardStarShape: Shape {
    var innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let w = rect.width / 2
        let h = rect.height / 2
        let ix = w * innerRatio
        let iy = h * innerRatio
        var p = Path()

        p.move(to: CGPoint(x: center.x, y: center.y - h))
        p.addQuadCurve(
            to: CGPoint(x: center.x + w, y: center.y),
            control: CGPoint(x: center.x + ix, y: center.y - iy)
        )
        p.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y + h),
            control: CGPoint(x: center.x + ix, y: center.y + iy)
        )
        p.addQuadCurve(
            to: CGPoint(x: center.x - w, y: center.y),
            control: CGPoint(x: center.x - ix, y: center.y + iy)
        )
        p.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y - h),
            control: CGPoint(x: center.x - ix, y: center.y - iy)
        )

        return p
    }
}

struct RippleEffectView: View {
    let position: CGPoint
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
        .position(position)
        .onAppear {
            withAnimation(.easeOut(duration: 2.0)) {
                progress = 1.0
            }
        }
    }
}
