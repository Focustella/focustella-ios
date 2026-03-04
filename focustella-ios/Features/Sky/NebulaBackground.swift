import SwiftUI

struct NebulaBackground: View {
    let size: CGSize
    let maxRadius: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.12, blue: 0.24),
                    Color(red: 0.04, green: 0.07, blue: 0.17),
                    Color(red: 0.02, green: 0.03, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.33, green: 0.54, blue: 1.0).opacity(0.36))
                .frame(width: maxRadius * 2.0, height: maxRadius * 2.0)
                .position(x: size.width * 0.2, y: size.height * 0.2)
                .blur(radius: 70)

            Circle()
                .fill(Color(red: 0.45, green: 0.86, blue: 0.95).opacity(0.28))
                .frame(width: maxRadius * 1.8, height: maxRadius * 1.8)
                .position(x: size.width * 0.82, y: size.height * 0.24)
                .blur(radius: 80)

            Circle()
                .fill(Color(red: 0.76, green: 0.55, blue: 1.0).opacity(0.22))
                .frame(width: maxRadius * 1.7, height: maxRadius * 1.7)
                .position(x: size.width * 0.76, y: size.height * 0.78)
                .blur(radius: 92)

            Circle()
                .fill(Color(red: 0.42, green: 0.58, blue: 0.96).opacity(0.22))
                .frame(width: maxRadius * 1.7, height: maxRadius * 1.7)
                .position(x: size.width * 0.24, y: size.height * 0.78)
                .blur(radius: 92)

            LinearGradient(
                colors: [
                    Color(red: 0.45, green: 0.66, blue: 1.0, opacity: 0.12),
                    .clear,
                    Color(red: 0.66, green: 0.46, blue: 0.96, opacity: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    .clear,
                    Color.black.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .frame(width: size.width, height: size.height)
        .ignoresSafeArea()
    }
}
