// 📂 Features/Session/Views/ActiveSessionView.swift
import SwiftUI

struct ActiveSessionView: View {
    @ObservedObject var viewModel: ActiveSessionViewModel
    @State private var newItemTitle: String = ""
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProgressView(value: viewModel.progress)
                .tint(.blue)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.progress)
            
            List {
                // 1. 할 일 목록 섹션
                Section {
                    ForEach(viewModel.activeItems) { item in
                        ChecklistRow(item: item) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.toggleItem(id: item.id)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: viewModel.removeActiveItem)
                }
                
                // 2. 할 일 추가 섹션
                Section {
                    // 🔥 [튜토리얼 가이드 1] 할 일이 텅 비어있을 때
                    if !hasSeenTutorial && viewModel.activeItems.isEmpty {
                        Text("👇 오늘 할 일을 하나 적고 추가해보세요!")
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                            .modifier(ActiveBounceAnimation())
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.bottom, 4)
                    }
                    
                    // 🔥 [튜토리얼 가이드 2] 할 일은 추가했는데 아직 체크 안 했을 때
                    if !hasSeenTutorial && !viewModel.activeItems.isEmpty && !viewModel.canComplete {
                        Text("👆 추가한 할 일을 터치해서 완료해 보세요!")
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                            .modifier(ActiveBounceAnimation())
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.bottom, 4)
                    }
                    
                    // 입력 필드 UI
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.6))
                        
                        TextField("세션 중 새로운 할 일 추가...", text: $newItemTitle)
                            .font(.system(size: 16, weight: .medium))
                            .onSubmit { addNewItem() }
                        
                        Button(action: addNewItem) {
                            Text("추가")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .opacity(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
                        .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        .animation(.easeInOut(duration: 0.2), value: newItemTitle)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            
            Spacer()
            
            // 🔥 [튜토리얼 가이드 3] 모두 완료(100%) 되어서 완료 버튼을 누를 수 있을 때
            if !hasSeenTutorial && viewModel.canComplete {
                Text("👇 완벽해요! 이제 세션 완료 버튼을 눌러주세요!")
                    .font(.subheadline.bold())
                    .foregroundColor(.blue)
                    .modifier(ActiveBounceAnimation())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
            }
            
            // 3. 하단 완료 버튼
            Button(action: {
                Task { await viewModel.completeDailySession() }
            }) {
                Text("완료하기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(!viewModel.canComplete)
            .padding()
        }
    }
    
    private func addNewItem() {
        guard !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            viewModel.addActiveItem(title: newItemTitle)
            newItemTitle = ""
        }
    }
}

// MARK: - 🎈 툴팁용 둥둥 떠다니는 애니메이션
private struct ActiveBounceAnimation: ViewModifier {
    @State private var isBouncing = false
    func body(content: Content) -> some View {
        content
            .offset(y: isBouncing ? 4 : -4)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isBouncing = true
                }
            }
    }
}
