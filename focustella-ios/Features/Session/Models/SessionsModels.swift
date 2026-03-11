// Features/Session/Models/SessionModels.swift

import Foundation

struct ChecklistItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    enum CodingKeys: String, CodingKey {
            case id = "itemUuid"
            case title
            case isCompleted
        }
}

struct ChecklistTemplate: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var items: [ChecklistItem]
}

// 🔥 변경점 1: 서버 전송용 DTO (String -> Array)
struct DailySessionSaveRequest: Codable {
    let timestamp: String
    let items: [ChecklistItem] // checklists(String) 대신 명확한 배열 사용
    // 🔥 JSON으로 인코딩될 때의 Key 이름을 서버 스펙과 맞춰주는 역할
    enum CodingKeys: String, CodingKey {
            case timestamp
            case items = "checklists" // 클라이언트의 items를 서버의 checklists로 매핑!
    }
}

// 🔥 변경점 2: 서버 수신용 DTO (String -> Array)
struct FetchedDailySession: Identifiable, Codable {
    var id: UUID = UUID()
    let timestamp: String
    let items: [ChecklistItem] // 서버에서 넘겨주는 JSON 배열을 바로 매핑
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case items = "checklists" // 백엔드 JSON 키가 여전히 "checklists"라면 매핑, "items"로 바꿨다면 이 줄도 삭제!
    }
}
    
