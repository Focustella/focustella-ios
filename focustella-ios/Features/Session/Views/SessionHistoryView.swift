// 📂 Features/Session/Views/SessionHistoryView.swift
import SwiftUI

struct SessionHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DailySessionViewModel
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isFetchingHistory {
                    ProgressView("서버에서 기록을 불러오는 중...")
                } else if viewModel.fetchedSessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("서버에 저장된 일일 세션 기록이 없습니다.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(viewModel.fetchedSessions) { session in
                        Section {
                            // 🔥 수정: parsedItems 대신 checklists 사용
                            ForEach(session.checklists) { item in
                                HStack(spacing: 12) {
                                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(item.isCompleted ? .green : .gray.opacity(0.3))
                                    
                                    Text(item.title)
                                        .font(.subheadline)
                                        .strikethrough(item.isCompleted, color: .gray)
                                        .foregroundColor(item.isCompleted ? .secondary : .primary)
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            Text(formatTimestamp(session.timestamp))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("서버 저장 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.fetchSessionHistory() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            // 🔥 Task 대신 onAppear 사용 권장 (시점 이슈 방지)
            .onAppear {
                Task {
                    await viewModel.fetchSessionHistory()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func formatTimestamp(_ timestamp: String) -> String {
        let formatter = DateFormatter()
        // 서버에서 오는 ISO8601 포맷(yyyy-MM-dd'T'HH:mm:ss'Z')에 맞게 수정
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        // UTC 시간대로 올 경우 로컬 타임존으로 변환
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy년 M월 d일 HH:mm 완료"
            // 기기의 로컬 타임존으로 표시
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }
        
        return timestamp.components(separatedBy: "T").first ?? timestamp
    }
}
