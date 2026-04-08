import SwiftUI

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
