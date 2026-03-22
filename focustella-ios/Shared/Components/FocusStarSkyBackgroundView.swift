import SwiftUI

struct FocusStarSkyBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [FocusStarPalette.skyTop, FocusStarPalette.skyMid, FocusStarPalette.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(FocusStarPalette.goldGlow.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 64)
                .offset(x: -150, y: -310)

            Circle()
                .fill(FocusStarPalette.cyanGlow.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 86)
                .offset(x: 160, y: 340)

            NightSkyStarField(seed: 20260308, count: 96)
        }
        .allowsHitTesting(false)
    }
}
