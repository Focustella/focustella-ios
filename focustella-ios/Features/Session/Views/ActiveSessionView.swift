// 📂 Features/Session/Views/ActiveSessionView.swift
import SwiftUI

struct ActiveSessionView: View {
    @ObservedObject var viewModel: ActiveSessionViewModel
    @State private var newItemTitle: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProgressView(value: viewModel.progress)
                .tint(.blue)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.progress)
            
            List {
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
                
                Section {
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
