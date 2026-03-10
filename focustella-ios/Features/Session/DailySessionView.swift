import SwiftUI

struct DailySessionView: View {
    @StateObject private var viewModel = DailySessionViewModel()
    private let studyModes = ["수학문제", "알고리즘", "토익RC"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("공부 방식 선택")
                .font(.headline)

            Picker("공부 방식", selection: $viewModel.selectedStudyMode) {
                ForEach(studyModes, id: \.self) { mode in
                    Text(mode).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Button("완료하기") {
                viewModel.completeDailySession()
            }
            .buttonStyle(.borderedProminent)

            Text("최근 완료한 일일 세션 목록(최신순)")
                .font(.headline)
                .padding(.top, 8)

            List(viewModel.records) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.studyMode)
                        .font(.headline)
                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .navigationTitle("일일 세션")
    }
}

#Preview {
    NavigationStack {
        DailySessionView()
    }
}

