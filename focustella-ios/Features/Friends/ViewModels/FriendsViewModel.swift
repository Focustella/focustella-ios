import SwiftUI
import Combine

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var pendingRequests: [FriendRequest] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    @Published var newFriendID: String = ""

    private let apiClient = APIClient.shared

    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "userId") ?? ""
    }

    // 친구 목록 + 받은 요청 한 번에 로드 (GET /api/v1/friend?userId={userId})
    func fetchFriends() {
        guard !currentUserId.isEmpty else {
            print("⚠️ [Friends] userId가 없어 fetchFriends 스킵")
            return
        }
        print("📡 [Friends] fetchFriends 요청 - userId: \(currentUserId)")
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let response: APIResponse<[FriendRelationDTO]> = try await apiClient.get(
                    "/api/v1/friend",
                    queryItems: [URLQueryItem(name: "userId", value: currentUserId)]
                )
                print("✅ [Friends] fetchFriends 응답 - success: \(response.success), 항목 수: \(response.data?.count ?? 0)")

                guard response.success, let relations = response.data else {
                    print("⚠️ [Friends] fetchFriends 응답 실패 또는 data nil")
                    return
                }

                friends = relations
                    .filter { $0.status == "ACCEPTED" }
                    .map { dto in
                        let otherId = dto.requesterId == currentUserId ? dto.receiverId : dto.requesterId
                        return Friend(id: otherId, name: otherId)
                    }
                print("👥 [Friends] 친구 목록: \(friends.map(\.id))")

                pendingRequests = relations
                    .filter { $0.status == "PENDING" && $0.receiverId == currentUserId }
                    .map { dto in
                        FriendRequest(id: dto.id, senderName: dto.requesterId)
                    }
                print("📬 [Friends] 받은 요청: \(pendingRequests.map(\.id))")
            } catch {
                print("🚨 [Friends] fetchFriends 실패: \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }

    // 친구 요청 보내기 (POST /api/v1/friend/request)
    func sendFriendRequest() {
        guard !newFriendID.isEmpty, !currentUserId.isEmpty else {
            print("⚠️ [Friends] sendFriendRequest 스킵 - newFriendID 또는 userId 없음")
            return
        }
        let receiverId = newFriendID
        newFriendID = ""
        print("📡 [Friends] sendFriendRequest 요청 - requesterId: \(currentUserId), receiverId: \(receiverId)")

        Task {
            do {
                let body = FriendRequestBody(requesterId: currentUserId, receiverId: receiverId)
                let response: APIResponse<FriendRelationDTO> = try await apiClient.post(
                    "/api/v1/friend/request",
                    body: body
                )
                print("✅ [Friends] sendFriendRequest 응답 - success: \(response.success), relationId: \(response.data?.id ?? "nil")")
            } catch {
                print("🚨 [Friends] sendFriendRequest 실패: \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }

    // 친구 요청 수락/거절 (POST /api/v1/friend/accept)
    func respondToRequest(requestID: String, isAccepted: Bool) {
        print("📡 [Friends] respondToRequest - relationId: \(requestID), accept: \(isAccepted)")
        pendingRequests.removeAll { $0.id == requestID }

        Task {
            do {
                let body = FriendAcceptBody(relationId: requestID, accept: isAccepted)
                let response: APIResponse<EmptyData> = try await apiClient.post(
                    "/api/v1/friend/accept",
                    body: body
                )
                print("✅ [Friends] respondToRequest 응답 - success: \(response.success)")
                if isAccepted {
                    fetchFriends()
                }
            } catch {
                print("🚨 [Friends] respondToRequest 실패: \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }
}
