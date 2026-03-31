// 📂 Features/Session/Views/TemplateSelectionView.swift
import SwiftUI

struct TemplateSelectionView: View {
    @ObservedObject var templateViewModel: TemplateViewModel
    @ObservedObject var activeViewModel: ActiveSessionViewModel
    @Binding var showingAddTemplate: Bool
    @Binding var templateToEdit: ChecklistTemplate?
    
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    
    var body: some View {
        Group {
            if templateViewModel.templates.isEmpty {
                VStack(spacing: 24) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    VStack(spacing: 8) {
                        // 🔥 튜토리얼용 텍스트 분기
                        Text(hasSeenTutorial ? "저장된 템플릿이 없습니다" : "일일 세션을 시작해볼까요?")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(hasSeenTutorial ? "새로운 템플릿을 만들거나,\n빈 세션으로 바로 공부를 시작해보세요." : "템플릿 없이 빈 세션으로\n자유롭게 시작할 수 있어요!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 12) {
                        if !hasSeenTutorial {
                            Text("👇 여기를 눌러 바로 시작해봐요!")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                                .padding(.bottom, -4)
                        }
                        
                        Button(action: {
                            withAnimation { activeViewModel.startEmptySession() }
                        }) {
                            Text(hasSeenTutorial ? "템플릿 없이 바로 시작" : "바로 시작하기") // 튜토리얼일 땐 문구를 더 직관적으로
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        
                        // 🌟 튜토리얼 중에는 "새 템플릿 만들기" 버튼을 아예 숨깁니다!
                        if hasSeenTutorial {
                            Button(action: {
                                showingAddTemplate = true
                            }) {
                                Text("새 템플릿 만들기")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else {
                List {
                    Section(header: Text("내 템플릿")) {
                        ForEach(templateViewModel.templates) { template in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { templateViewModel.expandedTemplateID == template.id },
                                    set: { isExpanded in
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            templateViewModel.expandedTemplateID = isExpanded ? template.id : nil
                                        }
                                    }
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(template.items) { item in
                                        HStack(spacing: 8) {
                                            Image(systemName: "circle")
                                                .foregroundColor(.gray.opacity(0.5))
                                                .font(.system(size: 12))
                                            Text(item.title)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    HStack {
                                        Button(action: { templateToEdit = template }) {
                                            Text("수정")
                                                .font(.subheadline)
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.secondary)
                                        
                                        Button(action: {
                                            // 🔥 템플릿으로 세션 시작도 ActiveViewModel에게 시킵니다!
                                            withAnimation {
                                                activeViewModel.startSession(with: template)
                                            }
                                        }) {
                                            Text("진행")
                                                .font(.subheadline)
                                                .bold()
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.blue)
                                    }
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("\(template.items.count)개의 항목")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .tint(.gray)
                        }
                        .onDelete(perform: templateViewModel.deleteTemplate)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}
