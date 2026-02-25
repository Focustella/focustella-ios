import Foundation

// API: /api/v1/friends 응답에 해당하는 모델
struct Friend: Identifiable, Hashable {
    let id: String
    let name: String
    // 추후 별자리 정보 등 추가
}

// API: /api/v1/friends/requests 응답에 해당하는 모델
struct FriendRequest: Identifiable, Hashable {
    let id: String
    let senderName: String
}
