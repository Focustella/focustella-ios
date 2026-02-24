import SwiftUI

struct FocusSessionView: View {
    @StateObject private var viewModel = FocusSessionViewModel()
    private let targetOptions = [25, 50, 75]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("목표 시간(분)")
                .font(.headline)

            Picker("목표 시간", selection: $viewModel.targetMinutes) {
                ForEach(targetOptions, id: \.self) { value in
                    Text("\(value)분").tag(value)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 8) {
                Text(timeString(from: viewModel.elapsedSeconds))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("상태: \(viewModel.state.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("시작") {
                    viewModel.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.state != .idle)

                Button("일시정지") {
                    viewModel.pause()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.state != .running)

                Button("재개") {
                    viewModel.resume()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.state != .paused)

                Button("종료") {
                    viewModel.stop()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.state == .idle)
            }

            Text("최근 완료한 집중 세션 목록(최신순)")
                .font(.headline)
                .padding(.top, 8)

            List(viewModel.records) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text("목표: \(record.targetMinutes)분 · 실제: \(formatActual(seconds: record.actualSeconds))")
                        .font(.headline)
                    Text(record.endedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .navigationTitle("집중 세션")
    }

    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func formatActual(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return "\(minutes)분 \(remainingSeconds)초"
    }
}

#Preview {
    NavigationStack {
        FocusSessionView()
    }
}

