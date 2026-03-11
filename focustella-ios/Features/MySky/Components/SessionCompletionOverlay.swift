import SwiftUI

struct SessionCompletionOverlay: View {
    let showRecordButton: Bool
    let onRecord: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("새로운 별자리를 관측했어요")
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("이번 집중 세션의 흐름을 짧게 남겨보세요.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer(minLength: 0)

                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(10)
                    .background(Color.white.opacity(0.1), in: Circle())
            }

            if showRecordButton {
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)

                    Button(action: onRecord) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 15, weight: .semibold))

                            Text("세션 기록하기")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            Color.white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}
