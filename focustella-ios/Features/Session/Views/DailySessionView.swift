// 📂 Features/Session/Views/DailySessionView.swift
import SwiftUI

struct DailySessionView: View {
    @StateObject private var viewModel = DailySessionViewModel()
    @State private var showingAddTemplate = false
    @State private var templateToEdit: ChecklistTemplate?
    @State private var showingHistorySheet = false
    @State private var showingCancelAlert = false
    
    var body: some View {
        NavigationStack {
            Group {
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
            .navigationTitle(viewModel.isSessionActive ? "세션 진행 중" : "일일 세션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.isSessionActive {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("다시 선택") { showingCancelAlert = true }
                            .tint(.red)
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
            .alert("안내", isPresented: $viewModel.showCompletionAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("오늘의 체크리스트를 완료했어요!")
            }
            .alert("세션 취소", isPresented: $showingCancelAlert) {
                Button("계속 진행", role: .cancel) { }
                Button("초기화", role: .destructive) {
                    withAnimation { viewModel.cancelSession() }
                }
            } message: {
                Text("현재 진행 중인 세션이 초기화됩니다.\n템플릿을 다시 선택하시겠습니까?")
            }
            .sheet(isPresented: $showingAddTemplate) {
                AddTemplateView(viewModel: viewModel)
            }
            .sheet(item: $templateToEdit) { template in
                EditTemplateView(viewModel: viewModel, template: template)
            }
            .sheet(isPresented: $showingHistorySheet) {
                SessionHistoryView(viewModel: viewModel)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
