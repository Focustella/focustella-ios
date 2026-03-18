// 📂 Features/Session/Views/DailySessionView.swift
import SwiftUI

struct DailySessionView: View {
    @Environment(\.scenePhase) private var scenePhase // 앱 상태 감지용
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DailySessionViewModel()
    @State private var showingAddTemplate = false
    @State private var templateToEdit: ChecklistTemplate?
    @State private var showingHistorySheet = false
    @State private var showingCancelAlert = false
    
    var body: some View {
        NavigationStack {
            Group {
                // 🔥 1. 오늘 이미 완료했다면 이 화면을 보여줍니다.
                if viewModel.hasCompletedToday {
                    VStack(spacing: 20) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)
                        Text("오늘은 이미 일일세션을 완료했어요!")
                            .font(.title2.bold())
                        Text("내일 06시 이후에 다시 만나요 🌌")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // 2. 아직 안 했다면 기존 세션 화면을 보여줍니다.
                    if viewModel.isSessionActive {
                        ActiveSessionView(viewModel: viewModel)
                    } else {
                        TemplateSelectionView(
                            viewModel: viewModel,
                            showingAddTemplate: $showingAddTemplate,
                            templateToEdit: $templateToEdit
                        )
                    }
                }
            }
            .navigationTitle(viewModel.isSessionActive && !viewModel.hasCompletedToday ? "세션 진행 중" : "일일 세션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                            // 🔥 1. 오늘 완료한 상태라도 '기록 보기' 버튼은 보여줍니다!
                            if viewModel.hasCompletedToday {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button(action: { showingHistorySheet = true }) {
                                        Image(systemName: "list.clipboard")
                                    }
                                }
                            } else {
                                // 🔥 2. 아직 안 한 상태의 기존 로직
                                if viewModel.isSessionActive {
                                    ToolbarItem(placement: .navigationBarLeading) {
                                        Button("다시 선택") { showingCancelAlert = true }.tint(.red)
                                    }
                                } else {
                                    ToolbarItem(placement: .navigationBarLeading) {
                                        Button(action: { showingHistorySheet = true }) {
                                            Image(systemName: "list.clipboard")
                                        }
                                    }
                                    ToolbarItem(placement: .navigationBarTrailing) {
                                        Button(action: { showingAddTemplate = true }) {
                                            Image(systemName: "plus")
                                        }
                                    }
                                }
                            }
                        }
            // 🔥 핵심 변경: 세션이 완료되면 창을 닫고 MySkyView로 신호를 냅니다!
            .onChange(of: viewModel.showCompletionAlert) { _, isCompleted in
                if isCompleted {
                    viewModel.showCompletionAlert = false // 상태 초기화
                    dismiss() // 1. 일일 세션 창 닫기
                    
                    // 2. MySkyView에 "별을 만들어라!" 하고 방송하기
                    NotificationCenter.default.post(name: Notification.Name("DailySessionCompleted"), object: nil)
                }
            }
            .alert("세션 취소", isPresented: $showingCancelAlert) {
                Button("계속 진행", role: .cancel) { }
                Button("초기화", role: .destructive) {
                    withAnimation { viewModel.cancelSession() }
                }
            } message: {
                Text("현재 진행 중인 세션이 초기화됩니다.\n템플릿을 다시 선택하시겠습니까?")
            }
            .sheet(isPresented: $showingAddTemplate) { AddTemplateView(viewModel: viewModel) }
            .sheet(item: $templateToEdit) { template in EditTemplateView(viewModel: viewModel, template: template) }
            .sheet(isPresented: $showingHistorySheet) { SessionHistoryView(viewModel: viewModel) }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // 🔥 화면이 나타날 때나 백그라운드에서 돌아올 때 '오늘 완료했는지' 다시 점검
        .onAppear {
            viewModel.refreshTodayStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.refreshTodayStatus()
            }
        }
    }
}
