// 📂 Features/Session/Views/DailySessionView.swift
import SwiftUI

struct DailySessionView: View {
    @Environment(\.scenePhase) private var scenePhase // 앱 상태 감지용
    @Environment(\.dismiss) private var dismiss
    
    // 🔥 1. 만능 뷰모델 1개를 지우고, 용도별로 3개로 나누어 선언합니다!
    @StateObject private var activeViewModel = ActiveSessionViewModel()
    @StateObject private var templateViewModel = TemplateViewModel()
    @StateObject private var historyViewModel = SessionHistoryViewModel()
    
    @State private var showingAddTemplate = false
    @State private var templateToEdit: ChecklistTemplate?
    @State private var showingHistorySheet = false
    @State private var showingCancelAlert = false
    
    var body: some View {
        NavigationStack {
            Group {
                // 🔥 2. 세션의 '상태(진행중, 완료여부)'는 모두 activeViewModel이 담당합니다.
                if activeViewModel.hasCompletedToday {
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
                    if activeViewModel.isSessionActive {
                        ActiveSessionView(viewModel: activeViewModel)
                    } else {
                        // 🔥 3. 아까 수정했던 대로 두 개의 뷰모델을 넘겨줍니다!
                        TemplateSelectionView(
                            templateViewModel: templateViewModel,
                            activeViewModel: activeViewModel,
                            showingAddTemplate: $showingAddTemplate,
                            templateToEdit: $templateToEdit
                        )
                    }
                }
            }
            .navigationTitle(activeViewModel.isSessionActive && !activeViewModel.hasCompletedToday ? "세션 진행 중" : "일일 세션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if activeViewModel.hasCompletedToday {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingHistorySheet = true }) {
                            Image(systemName: "list.clipboard")
                        }
                    }
                } else {
                    if activeViewModel.isSessionActive {
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
            .onChange(of: activeViewModel.showCompletionAlert) { _, isCompleted in
                if isCompleted {
                    activeViewModel.showCompletionAlert = false // 상태 초기화
                    dismiss() // 1. 일일 세션 창 닫기
                    
                    // 2. MySkyView에 "별을 만들어라!" 하고 방송하기
                    NotificationCenter.default.post(name: Notification.Name("DailySessionCompleted"), object: nil)
                }
            }
            .alert("세션 취소", isPresented: $showingCancelAlert) {
                Button("계속 진행", role: .cancel) { }
                Button("초기화", role: .destructive) {
                    withAnimation { activeViewModel.cancelSession() }
                }
            } message: {
                Text("현재 진행 중인 세션이 초기화됩니다.\n템플릿을 다시 선택하시겠습니까?")
            }
            // 🔥 4. 각각의 바텀시트(Sheet)에 맞는 전용 뷰모델을 넘겨줍니다!
            .sheet(isPresented: $showingAddTemplate) {
                AddTemplateView(viewModel: templateViewModel)
            }
            .sheet(item: $templateToEdit) { template in
                EditTemplateView(viewModel: templateViewModel, template: template)
            }
            .sheet(isPresented: $showingHistorySheet) {
                SessionHistoryView(viewModel: historyViewModel)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            activeViewModel.refreshTodayStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                activeViewModel.refreshTodayStatus()
            }
        }
    }
}
