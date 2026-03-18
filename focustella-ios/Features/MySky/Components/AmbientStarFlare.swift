import SwiftUI

struct AmbientStarFlare: View {
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
                .blur(radius: thickness * 0.45)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, color, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: thickness, height: length)
                .blur(radius: thickness * 0.45)
        }
        .allowsHitTesting(false)
    }
}
