// 📂 Features/Friends/ViewModels/FriendsViewModel.swift
import SwiftUI
import Combine

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var pendingRequests: [FriendRequest] = []
    @Published var isLoading: Bool = false
    
    // 🔥 1. 알림창 제어를 위한 변수 추가
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    
    @Published var searchText: String = ""
    @Published var searchResults: [UserSearchDTO] = []
    
    private var hasFetchedInitialData: Bool = false
    
    var myProfileText: String {
        "\(AuthSessionStore.myNickname)#\(AuthSessionStore.myUserCode)"
    }

    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "userId") ?? ""
    }

    private let fetchFriendsUseCase = FetchFriendsUseCase()
    private let sendFriendRequestUseCase = SendFriendRequestUseCase()
    private let respondToFriendRequestUseCase = RespondToFriendRequestUseCase()
    private let searchUsersUseCase = SearchUsersUseCase()
    
    init() { }

    func fetchFriendsIfNeeded() {
        guard !hasFetchedInitialData else { return }
        fetchFriends()
    }

    func fetchFriends() {
        guard !currentUserId.isEmpty else { return }
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let result = try await fetchFriendsUseCase.execute(userId: currentUserId)
                self.friends = result.friends
                self.pendingRequests = result.pendingRequests
                self.hasFetchedInitialData = true
            } catch {
                print("🚨 프렌즈 목록 조회 실패: \(error)")
            }
        }
    }

    func executeSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            self.searchResults = []
            return
        }
        
        Task {
            do {
                let results = try await searchUsersUseCase.execute(keyword: searchText)
                self.searchResults = results
            } catch {
                self.searchResults = []
            }
        }
    }

    // 🔥 2. 친구 요청 보내기 (성공/에러 알림 분기 처리)
    func sendFriendRequest(to receiverId: String) {
        guard !currentUserId.isEmpty else { return }
        Task {
            do {
                try await sendFriendRequestUseCase.execute(requesterId: currentUserId, receiverId: receiverId)
                
                // ✅ 성공 처리
                self.searchText = ""
                self.fetchFriends()
                self.alertMessage = "친구 요청을 보냈습니다! 💌"
                self.showAlert = true
                
            } catch {
                // 🚨 에러 처리 (백엔드 에러 코드 파싱)
                let errorString = String(describing: error).uppercased()
                
                if errorString.contains("SELF_REQUEST_NOT_ALLOWED") || errorString.contains("400") {
                    self.alertMessage = "자기 자신에게는 친구 요청을 보낼 수 없습니다. 😅"
                } else if errorString.contains("ALREADY_FRIEND_OR_PENDING") || errorString.contains("409") {
                    self.alertMessage = "이미 친구이거나 요청 대기 중인 사용자입니다. 🤝"
                } else {
                    self.alertMessage = "친구 요청에 실패했습니다. 잠시 후 다시 시도해 주세요."
                }
                self.showAlert = true
            }
        }
    }

    // 🔥 3. 친구 요청 수락/거절 (성공/에러 알림 분기 처리)
    func respondToRequest(requestID: String, isAccepted: Bool) {
        Task {
            do {
                try await respondToFriendRequestUseCase.execute(relationId: requestID, isAccepted: isAccepted)
                
                // ✅ 성공 처리
                self.fetchFriends()
                self.alertMessage = isAccepted ? "친구 요청을 수락했습니다! 🎉" : "친구 요청을 거절했습니다."
                self.showAlert = true
                
            } catch {
                // 🚨 에러 처리
                let errorString = String(describing: error).uppercased()
                
                if errorString.contains("FRIEND_REQUEST_NOT_FOUND") || errorString.contains("404") {
                    self.alertMessage = "이미 처리되었거나 찾을 수 없는 요청입니다. 🥲"
                } else {
                    self.alertMessage = "요청 처리에 실패했습니다. 잠시 후 다시 시도해 주세요."
                }
                self.showAlert = true
                self.fetchFriends() // 꼬인 상태 복구를 위해 강제 새로고침
            }
        }
    }
}
