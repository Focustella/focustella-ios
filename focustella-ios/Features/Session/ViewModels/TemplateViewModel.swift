// 📂 Features/Session/ViewModels/TemplateViewModel.swift
import SwiftUI
import Combine

@MainActor
final class TemplateViewModel: ObservableObject {
    @Published var templates: [ChecklistTemplate] = []
    @Published var expandedTemplateID: UUID? = nil
    
    private let templatesKey = "Focustella_ChecklistTemplates"
    
    init() {
        loadTemplates()
    }
    
    // MARK: - Templates 로직
    func loadTemplates() {
        if let data = UserDefaults.standard.data(forKey: templatesKey),
           let decoded = try? JSONDecoder().decode([ChecklistTemplate].self, from: data) {
            self.templates = decoded
        }
    }
    
    private func saveTemplates() {
        if let encoded = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(encoded, forKey: templatesKey)
        }
    }
    
    func addTemplate(_ template: ChecklistTemplate) {
        templates.append(template)
        saveTemplates()
    }
    
    func updateTemplate(_ updatedTemplate: ChecklistTemplate) {
        if let index = templates.firstIndex(where: { $0.id == updatedTemplate.id }) {
            templates[index] = updatedTemplate
            saveTemplates()
        }
    }
    
    func deleteTemplate(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        saveTemplates()
    }
}
