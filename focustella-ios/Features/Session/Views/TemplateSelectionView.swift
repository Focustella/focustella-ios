// 📂 Features/Session/Views/TemplateSelectionView.swift
import SwiftUI

struct TemplateSelectionView: View {
    @ObservedObject var viewModel: DailySessionViewModel
    @Binding var showingAddTemplate: Bool
    @Binding var templateToEdit: ChecklistTemplate?
    
    var body: some View {
        Group {
            if viewModel.templates.isEmpty {
                VStack(spacing: 24) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    VStack(spacing: 8) {
                        Text("저장된 템플릿이 없습니다")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("새로운 템플릿을 만들거나,\n빈 세션으로 바로 공부를 시작해보세요.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            withAnimation { viewModel.startEmptySession() }
                        }) {
                            Text("템플릿 없이 바로 시작")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        
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
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else {
                List {
                    Section(header: Text("내 템플릿")) {
                        ForEach(viewModel.templates) { template in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { viewModel.expandedTemplateID == template.id },
                                    set: { isExpanded in
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            viewModel.expandedTemplateID = isExpanded ? template.id : nil
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
                                            withAnimation {
                                                viewModel.startSession(with: template)
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
                        .onDelete(perform: viewModel.deleteTemplate)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}
