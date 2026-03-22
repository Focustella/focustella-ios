import Foundation

// MARK: - 공통 응답 래퍼 (temp.json 기반)
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let timestamp: String
}

// data가 null인 응답용 (예: /api/v1/friend/accept)
struct EmptyData: Decodable {}

// MARK: - 친구 관계 DTO
// GET /api/v1/friend?userId={userId} 응답 내 각 항목
struct FriendRelationDTO: Decodable, Identifiable {
    let id: String
    let requesterId: String
    let receiverId: String
    let status: String  // "ACCEPTED" | "PENDING"
}

// MARK: - 요청 Body
// POST /api/v1/friend/request
struct FriendRequestBody: Encodable {
    let requesterId: String
    let receiverId: String
}

// POST /api/v1/friend/accept
struct FriendAcceptBody: Encodable {
    let relationId: String
    let accept: Bool
}
