import SwiftUI

struct DeepSpaceMySkyBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.02, blue: 0.09),
                    Color(red: 0.03, green: 0.03, blue: 0.15),
                    Color(red: 0.02, green: 0.01, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color(red: 0.40, green: 0.30, blue: 0.88).opacity(0.12))
                .frame(width: 540, height: 540)
                .blur(radius: 90)
                .offset(x: -190, y: -220)

            Circle()
                .fill(Color(red: 0.26, green: 0.34, blue: 0.92).opacity(0.10))
                .frame(width: 640, height: 640)
                .blur(radius: 102)
                .offset(x: 220, y: 340)

            NightSkyStarField(
                count: 74,
                salt: "background-deep-space",
                profile: .wideSoft
            )
        }
        .allowsHitTesting(false)
    }
}
