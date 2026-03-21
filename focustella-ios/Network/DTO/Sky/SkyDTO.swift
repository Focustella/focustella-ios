import Foundation

struct SkyResponseDTO: Decodable {
    let ownerId: String
    let seed: Int64
    let dailyStars: [SkyDailyStarDTO]
    let focusConstellations: [FocusSessionRecordDTO]
}

struct SkyDailyStarDTO: Decodable {
    let sessionId: String
    let session: DailySessionRecordDTO
}

struct DailySessionRecordDTO: Decodable {
    let sessionId: String
    let userId: String
    let timestamp: String
    let checklists: [DailyChecklistRecordDTO]
}

struct DailyChecklistRecordDTO: Decodable {
    let itemUuid: String?
    let title: String
    let isCompleted: Bool
}
