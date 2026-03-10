// 📂 Features/Session/Views/AddTemplateView.swift
import SwiftUI

struct AddTemplateView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DailySessionViewModel
    
    @State private var templateName = ""
    @State private var newItemTitle = ""
    @State private var items: [ChecklistItem] = []
    
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
            .navigationTitle("새 템플릿 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let newTemplate = ChecklistTemplate(name: templateName, items: items)
                        viewModel.addTemplate(newTemplate)
                        dismiss()
                    }
                    .disabled(templateName.isEmpty || items.isEmpty)
                }
            }
        }
    }
}
