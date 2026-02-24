import SwiftUI

struct NebulaBackground: View {
    let size: CGSize
    let maxRadius: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.12))

            LinearGradient(
                colors: [
                    Color.white,
                    Color.white,
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            #if DEBUG
            Text("DEBUG WHITE BG")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.red)
                .padding(12)
                .background(Color.white.opacity(0.4))
                .cornerRadius(10)
                .position(x: 120, y: 80)
            #endif

            nebulaBlob(
                colors: [
                    Color.white.opacity(0.85),
                    Color.white.opacity(0.55),
                    .clear
                ],
                center: CGPoint(x: size.width * 0.18, y: size.height * 0.15),
                radius: maxRadius * 1.05,
                blur: 100
            )

            nebulaBlob(
                colors: [
                    Color.white.opacity(0.75),
                    Color.white.opacity(0.45),
                    .clear
                ],
                center: CGPoint(x: size.width * 0.72, y: size.height * 0.28),
                radius: maxRadius * 0.95,
                blur: 110
            )

            nebulaBlob(
                colors: [
                    Color.white.opacity(0.70),
                    Color.white.opacity(0.40),
                    .clear
                ],
                center: CGPoint(x: size.width * 0.40, y: size.height * 0.82),
                radius: maxRadius * 0.85,
                blur: 120
            )

            nebulaBlob(
                colors: [
                    Color.white.opacity(0.65),
                    Color.white.opacity(0.35),
                    .clear
                ],
                center: CGPoint(x: size.width * 0.85, y: size.height * 0.82),
                radius: maxRadius * 0.75,
                blur: 120
            )

            nebulaBlob(
                colors: [
                    Color.white.opacity(0.35),
                    .clear
                ],
                center: CGPoint(x: size.width * 0.55, y: size.height * 0.55),
                radius: maxRadius * 1.4,
                blur: 140
            )

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.multiply)
        }
        .compositingGroup()
        .frame(width: size.width, height: size.height)
        .ignoresSafeArea()
    }

    private func nebulaBlob(
        colors: [Color],
        center: CGPoint,
        radius: CGFloat,
        blur: CGFloat
    ) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: colors,
                    center: .center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
            .blur(radius: blur)
            .blendMode(.plusLighter)
            .opacity(0.85)
    }
}
