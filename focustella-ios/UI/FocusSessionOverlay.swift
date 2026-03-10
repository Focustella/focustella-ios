import SwiftUI

struct FocusSessionOverlay: View {
    let session: FocusSession
    let constellation: Constellation
    let remainingSeconds: Int
    let reduceMotion: Bool
    let highPerformanceMode: Bool
    let isDeveloperMode: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void
    let onAdvanceNextStar: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(constellation.name)
                .font(.headline)

            Text(timeString(from: remainingSeconds))
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text("밝힌 별 \(session.discoveredStarCount)/\(constellation.starCount)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ConstellationRenderer(
                constellation: constellation,
                discoveredStarCount: session.discoveredStarCount,
                showEdges: false,
                edgeProgress: 0,
                reduceMotion: reduceMotion,
                highPerformanceMode: highPerformanceMode
            )
            .frame(height: 150)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 10) {
                if isDeveloperMode {
                    Button("다음 별") {
                        onAdvanceNextStar()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }

                if session.status == .running {
                    Button("일시정지", action: onPause)
                        .buttonStyle(.bordered)
                } else if session.status == .paused {
                    Button("재개", action: onResume)
                        .buttonStyle(.borderedProminent)
                }

                Button("종료", role: .destructive, action: onCancel)
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func timeString(from totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
