// 📂 Features/Session/Components/FocusSessionOverlay.swift
import SwiftUI

struct FocusSessionOverlay: View {
    let session: FocusSession
    let remainingSeconds: Int
    let isDeveloperMode: Bool
    var isTutorial: Bool = false // 🔥 튜토리얼 모드 판별 플래그
    
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void
    let onAdvanceNextStar: () -> Void
    let onAdvanceFinalStar: () -> Void
    
    @State private var isConfirmingCancel: Bool = false
    @State private var resetCancelTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 10) {
            Text(timeString(from: remainingSeconds))
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)

            // 🔥 튜토리얼 중이 아닐 때만 기존 컨트롤 버튼들 표시
            if !isTutorial {
                HStack(spacing: 14) {
                    if isDeveloperMode {
                        HStack(spacing: 8) {
                            Button("다음 별") { onAdvanceNextStar() }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.black)
                                .frame(height: 40)
                                .padding(.horizontal, 14)
                                .background(Color.white, in: Capsule())

                            Button("마지막 별") { onAdvanceFinalStar() }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.black)
                                .frame(height: 40)
                                .padding(.horizontal, 14)
                                .background(Color.white, in: Capsule())
                        }
                    }

                    Button {
                        if session.status == .running { onPause() } else { onResume() }
                    } label: {
                        Text(session.status == .running ? "||" : "▶")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 40)
                            .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        if isConfirmingCancel {
                            onCancel()
                        } else {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { isConfirmingCancel = true }
                            resetCancelTask?.cancel()
                            resetCancelTask = Task { @MainActor in
                                try? await Task.sleep(for: .seconds(2.2))
                                guard !Task.isCancelled else { return }
                                withAnimation(.easeInOut(duration: 0.24)) { isConfirmingCancel = false }
                            }
                        }
                    } label: {
                        Text(isConfirmingCancel ? "중단하기" : "X")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(isConfirmingCancel ? .white : .black)
                            .frame(width: isConfirmingCancel ? 108 : 44, height: 40)
                            .background(isConfirmingCancel ? Color.red.opacity(0.82) : Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // 🔥 튜토리얼용 타임워프 이펙트 UI
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("타임워프 진행 중... 🚀")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.yellow)
                .frame(height: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onDisappear { resetCancelTask?.cancel() }
    }

    private func timeString(from totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 { return String(format: "%02d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
