import SwiftUI

struct MySkyBottomCTAView: View {
    let isVisible: Bool
    let bottomInset: CGFloat
    let onTapDaily: () -> Void
    let onTapFocus: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onTapDaily) {
                Text("오늘 하루 계획하기")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 220, height: 48)
                    .background(Color.white.opacity(0.16), in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onTapFocus) {
                Text("집중 세션 시작")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(width: 220, height: 48)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, bottomInset)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
    }
}
