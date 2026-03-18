// 📂 Features/Session/Models/SessionModels.swift
import Foundation

struct ChecklistItem: Identifiable, Codable, Equatable {
    // 서버의 itemUuid와 매칭됩니다.
    // 서버에서 UUID 문자열을 주므로, 디코딩 시 유연하게 대응하려면 UUID 타입이 좋습니다.
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

struct DailySessionSaveRequest: Codable {
    let timestamp: String
    let checklists: [ChecklistItem]
}

// 🔥 GET 요청 시 사용할 모델 리팩토링
struct FetchedDailySession: Identifiable, Codable {
    var id: UUID = UUID() // 로컬 List용 ID
    let timestamp: String
    
    // 🔥 중요: String에서 [ChecklistItem] 배열로 변경!
    // 이제 더 이상 parsedItems 같은 변환 로직이 필요 없습니다.
    let checklists: [ChecklistItem]
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case checklists
    }
}
