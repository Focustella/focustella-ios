import SwiftUI

struct InputProtectionBannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.62), in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }
}
