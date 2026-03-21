import Foundation

struct FocusSessionCreateRequestDTO: Encodable {
    let durationMinutes: Int
}

struct FocusSessionCreateResponseDTO: Decodable {
    let focusSessionId: String
    let constellationId: Int
    let durationMinutes: Int
    let minStarCount: Int
    let maxStarCount: Int
    let constellation: ConstellationDTO
}

struct FocusSessionSaveRequestDTO: Encodable {
    let sessionId: String
    let constellationId: Int
    let startedAt: String
    let endedAt: String
    let slotSeconds: Int
    let discoveredStarCount: Int
    let topicTags: [String]
    let rating: Int
    let freeText: String?
}

struct FocusSessionRecordDTO: Decodable {
    let sessionId: String
    let constellationId: Int
    let durationMinutes: Int
    let startedAt: String
    let endedAt: String
    let slotSeconds: Int
    let discoveredStarCount: Int
    let topicTags: [String]
    let rating: Int
    let freeText: String?
    let constellation: ConstellationDTO
}

struct UserTagDTO: Decodable {
    let id: Int
    let name: String
}

struct UserTagMutationRequestDTO: Encodable {
    let name: String
}
