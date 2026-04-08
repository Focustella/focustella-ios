import SwiftUI

struct AuroraMySkyBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.10, blue: 0.22),
                    Color(red: 0.03, green: 0.17, blue: 0.24),
                    Color(red: 0.01, green: 0.05, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.27, green: 0.83, blue: 0.67).opacity(0.16))
                .frame(width: 520, height: 520)
                .blur(radius: 82)
                .offset(x: -150, y: -260)

            Circle()
                .fill(Color(red: 0.20, green: 0.66, blue: 0.95).opacity(0.14))
                .frame(width: 620, height: 620)
                .blur(radius: 96)
                .offset(x: 180, y: 300)

            NightSkyStarField(
                count: 112,
                salt: "background-aurora",
                profile: .denseUpper
            )
        }
        .allowsHitTesting(false)
    }
}
