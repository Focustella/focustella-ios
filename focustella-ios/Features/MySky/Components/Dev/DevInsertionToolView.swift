import SwiftUI

struct DevInsertionToolView: View {
    @Binding var starStyle: StarAppearanceStyle
    @ObservedObject var coordinator: DevInsertionCoordinator
    let fixedUserSeed: Int64

    let isSessionRunning: Bool
    let onPlaceNextBatch: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Menu {
                Picker("별 모양", selection: $starStyle) {
                    ForEach(StarAppearanceStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 12))
                    Text(starStyle.rawValue)
                        .font(.caption.bold())
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.9), in: Capsule())
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
            }

            placementTool
        }
    }

    @ViewBuilder
    private var placementTool: some View {
        if coordinator.isCollapsed {
            Button {
                coordinator.isCollapsed = false
            } label: {
                Text("별 삽입 도구")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("별 삽입 도구")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        coordinator.isCollapsed = true
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Text("Seed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(fixedUserSeed)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Template")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Mixed (고정)")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Count: \(coordinator.batchCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Stepper("", value: $coordinator.batchCount, in: 1...12)
                        .labelsHidden()
                }

                HStack(spacing: 8) {
                    Button(coordinator.batchCount == 1 ? "다음 배치" : "\(coordinator.batchCount)개 배치") {
                        onPlaceNextBatch()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(isSessionRunning ? Color.white.opacity(0.28) : Color.white.opacity(0.96))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
                    .opacity(isSessionRunning ? 0.7 : 1.0)
                    .disabled(isSessionRunning)

                    Button("리셋") {
                        onReset()
                    }
                    .buttonStyle(.bordered)
                }

                Text(coordinator.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 240, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
    }
}
