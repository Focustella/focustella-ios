// 📂 Features/Session/Models/SessionModels.swift
import Foundation

struct ChecklistItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
}

struct ChecklistTemplate: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var items: [ChecklistItem]
}

struct DailySessionSaveRequest: Codable {
    let timestamp: String
    let checklists: String
}

struct FetchedDailySession: Identifiable, Codable {
    var id: UUID = UUID()
    let timestamp: String
    let checklists: String
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case checklists
    }
}

extension FetchedDailySession {
    var parsedItems: [ChecklistItem] {
        guard let data = checklists.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([ChecklistItem].self, from: data) else {
            return []
        }
        return decoded
    }
}
