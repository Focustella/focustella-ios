// 📂 Features/Friends/ViewModels/FriendsViewModel.swift
import SwiftUI
import Combine

// 🔥 임시 검색 결과 모델 (나중에 백엔드 API DTO로 교체하세요!)
struct UserSearchResult: Identifiable {
    let id: String
    let nickname: String
    let userCode: String
}

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var pendingRequests: [FriendRequest] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // 🔥 1. 네이티브 검색창을 위한 변수들
    @Published var searchText: String = ""
    @Published var searchResults: [UserSearchResult] = []
    private let searchUsersUseCase = SearchUsersUseCase()
    
    // 🔥 2. 내 정보 가져오기 (AuthSessionStore에서 바로 땡겨옴)
    var myProfileText: String {
        "\(AuthSessionStore.myNickname)#\(AuthSessionStore.myUserCode)"
    }

    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "userId") ?? ""
    }

    private let fetchFriendsUseCase = FetchFriendsUseCase()
    private let sendFriendRequestUseCase = SendFriendRequestUseCase()
    private let respondToFriendRequestUseCase = RespondToFriendRequestUseCase()
    private var cancellables = Set<AnyCancellable>() // 검색어 타이핑 방지용

    init() {
        // 🔥 3. 유저가 검색어를 다 치고 0.5초 쉴 때만 서버에 검색 요청을 날림 (서버 과부하 방지!)
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] keyword in
                guard let self = self else { return }
                if keyword.isEmpty {
                    self.searchResults = []
                } else {
                    self.searchUsers(keyword: keyword)
                }
            }
            .store(in: &cancellables)
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
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func searchUsers(keyword: String) {
            Task {
                do {
                    let results = try await searchUsersUseCase.execute(keyword: keyword)
                    self.searchResults = results
                    print("✅ [검색 성공] \(results.count)명 찾음!")
                    
                } catch let DecodingError.keyNotFound(key, context) {
                    // 🔥 "이 키보따리(변수)가 없대요!"
                    print("🚨 [디코딩 에러] 서버 JSON에 '\(key.stringValue)' 키가 없습니다! 위치: \(context.codingPath)")
                    self.searchResults = []
                } catch let DecodingError.typeMismatch(type, context) {
                    // 🔥 "글자인 줄 알았는데 숫자래요!"
                    print("🚨 [디코딩 에러] 타입이 안 맞습니다. 기대한 타입: \(type), 위치: \(context.codingPath)")
                    self.searchResults = []
                } catch let DecodingError.valueNotFound(type, context) {
                    // 🔥 "값이 null 이래요!"
                    print("🚨 [디코딩 에러] 값이 null입니다. 기대한 타입: \(type), 위치: \(context.codingPath)")
                    self.searchResults = []
                } catch {
                    // 기타 에러
                    print("🚨 [기타 에러] \(error.localizedDescription)")
                    self.searchResults = []
                }
            }
        }

    // 🔥 5. 친구 요청 보내기 (기존 TextField용 변수 대신 직접 ID를 받도록 수정)
    func sendFriendRequest(to receiverId: String) {
        guard !currentUserId.isEmpty else { return }
        Task {
            do {
                try await sendFriendRequestUseCase.execute(requesterId: currentUserId, receiverId: receiverId)
                // 성공 시 검색창 초기화 및 리스트 갱신
                self.searchText = ""
                self.fetchFriends()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func respondToRequest(requestID: String, isAccepted: Bool) {
        pendingRequests.removeAll { $0.id == requestID }
        Task {
            do {
                try await respondToFriendRequestUseCase.execute(relationId: requestID, isAccepted: isAccepted)
                if isAccepted { fetchFriends() }
            } catch {
                self.errorMessage = error.localizedDescription
                fetchFriends()
            }
        }
    }
}
