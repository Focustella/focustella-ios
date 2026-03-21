import SwiftUI
import Combine

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var pendingRequests: [FriendRequest] = []
    
    // UI에서 사용할 친구 추가 입력값
    @Published var newFriendID: String = ""
    
    // 1. 친구 목록 조회 (GET /api/v1/friends)
    func fetchFriends() {
        // TODO: 실제 API 호출 코드 작성
        // 임시 더미 데이터
        self.friends = [
            Friend(id: "user1", name: "김개발"),
            Friend(id: "user2", name: "이코딩")
        ]
    }
    
    // 2. 받은 친구 요청 조회 (GET /api/v1/friends/requests)
    func fetchRequests() {
        // TODO: 실제 API 호출 코드 작성
        self.pendingRequests = [
            FriendRequest(id: "req1", senderName: "박스위프트")
        ]
    }
    
    // 3. 친구 요청 보내기 (POST /api/v1/friends/requests)
    func sendFriendRequest() {
        guard !newFriendID.isEmpty else { return }
        
        // TODO: newFriendID를 파라미터로 API 호출
        print("\(newFriendID) 에게 친구 요청을 보냈습니다.")
        
        // 요청 후 입력창 초기화
        self.newFriendID = ""
    }
    
    // 4. 친구 요청 수락/거절 (POST or PUT or DELETE /api/v1/friends/requests/{id})
    func respondToRequest(requestID: String, isAccepted: Bool) {
        // TODO: requestID와 isAccepted 여부를 바탕으로 API 호출
        print("요청 ID \(requestID) 를 \(isAccepted ? "수락" : "거절") 했습니다.")
        
        // 임시로 UI에서 바로 제거
        self.pendingRequests.removeAll { $0.id == requestID }
        
        // 수락했을 경우 친구 목록을 다시 불러오는 로직 추가 가능
        if isAccepted {
            fetchFriends()
        }
    }
}
