import SwiftUI

struct LegacyMySkyBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.10, blue: 0.24),
                    Color(red: 0.04, green: 0.06, blue: 0.16),
                    Color(red: 0.02, green: 0.03, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.25, green: 0.38, blue: 0.78).opacity(0.20))
                .frame(width: 560, height: 560)
                .blur(radius: 70)
                .offset(x: -180, y: -260)

            Circle()
                .fill(Color(red: 0.36, green: 0.30, blue: 0.66).opacity(0.14))
                .frame(width: 620, height: 620)
                .blur(radius: 78)
                .offset(x: 210, y: 300)

            NightSkyStarField(seed: 20260301, count: 84)
        }
        .allowsHitTesting(false)
    }
}
