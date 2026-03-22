// 📂 Features/Session/Views/SessionHistoryView.swift
import SwiftUI

struct SessionHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SessionHistoryViewModel
    
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
                            // 🔥 수정: 모델에 맞춰 checklists 사용
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
        // 🔥 서버가 "Z"로 끝나는 ISO8601 표준 포맷을 보내주므로 전용 포매터 사용
        let formatter = ISO8601DateFormatter()
        
        if let date = formatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            // 한국 시간에 맞게 예쁘게 출력
            displayFormatter.dateFormat = "yyyy년 M월 d일 HH:mm 완료"
            // 기기의 로컬 타임존으로 표시
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }
        
        // 파싱 실패 시 T를 기준으로 날짜만이라도 보여주는 안전장치
        return timestamp.components(separatedBy: "T").first ?? timestamp
    }
}
