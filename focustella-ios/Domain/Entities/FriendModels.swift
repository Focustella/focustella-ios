import Foundation

// 내 친구 목록에 표시되는 항목
struct Friend: Identifiable, Hashable {
    let id: String    // 상대방 userId
    let name: String  // 현재는 userId로 표시 (추후 username/닉네임 API 연동 시 업데이트)
}

// 받은 친구 요청 항목
struct FriendRequest: Identifiable, Hashable {
    let id: String          // relation ID (수락/거절 API에 사용)
    let senderName: String  // 요청자 userId (추후 닉네임으로 교체)
}
