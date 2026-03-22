// 📂 Features/Session/Views/EditTemplateView.swift
import SwiftUI

struct EditTemplateView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: TemplateViewModel
    
    let originalTemplate: ChecklistTemplate
    
    @State private var templateName: String
    @State private var items: [ChecklistItem]
    @State private var newItemTitle = ""
    
    init(viewModel: TemplateViewModel, template: ChecklistTemplate) {
        self.viewModel = viewModel
        self.originalTemplate = template
        _templateName = State(initialValue: template.name)
        _items = State(initialValue: template.items)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("템플릿 이름") {
                    TextField("예: 주말 모드", text: $templateName)
                }
                
                Section("체크리스트 항목") {
                    ForEach(items) { item in
                        Text(item.title)
                    }
                    .onDelete { indexSet in
                        items.remove(atOffsets: indexSet)
                    }
                    
                    HStack {
                        TextField("할 일 추가", text: $newItemTitle)
                        Button("추가") {
                            guard !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            items.append(ChecklistItem(title: newItemTitle))
                            newItemTitle = ""
                        }
                    }
                }
            }
            .navigationTitle("템플릿 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let updated = ChecklistTemplate(id: originalTemplate.id, name: templateName, items: items)
                        viewModel.updateTemplate(updated)
                        dismiss()
                    }
                    .disabled(templateName.isEmpty || items.isEmpty)
                }
            }
        }
    }
}
