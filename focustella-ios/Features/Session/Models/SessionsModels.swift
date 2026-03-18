// Features/Session/Models/SessionModels.swift

import Foundation

struct ChecklistItem: Identifiable, Codable, Equatable {
    // 서버의 itemUuid와 매칭됩니다.
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id = "itemUuid"
        case title
        case isCompleted
    }
}

struct ChecklistTemplate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var items: [ChecklistItem]
}

// 🔥 서버 전송용 DTO (String -> Array)
struct DailySessionSaveRequest: Codable {
    let timestamp: String
    let checklists: [ChecklistItem] // 서버 스펙에 맞춰 checklists로 통일!
}

// 🔥 서버 수신용 DTO (String -> Array)
struct FetchedDailySession: Identifiable, Codable {
    var id: UUID = UUID() // 로컬 List용 ID
    let timestamp: String
    
    // 🔥 중요: String에서 [ChecklistItem] 배열로 변경!
    let checklists: [ChecklistItem]
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case checklists
    }
}
