import Foundation

final class FetchFriendsUseCase {
    private let repository: FriendRepository // 🔥 Interface 단어 제거
    init(repository: FriendRepository = FriendRepositoryImpl()) { self.repository = repository }
    
    func execute(userId: String) async throws -> (friends: [Friend], pendingRequests: [FriendRequest]) {
        return try await repository.fetchFriends(userId: userId)
    }
}

final class SendFriendRequestUseCase {
    private let repository: FriendRepository
    init(repository: FriendRepository = FriendRepositoryImpl()) { self.repository = repository }
    
    func execute(requesterId: String, receiverId: String) async throws {
        try await repository.sendRequest(requesterId: requesterId, receiverId: receiverId)
    }
}

final class RespondToFriendRequestUseCase {
    private let repository: FriendRepository
    init(repository: FriendRepository = FriendRepositoryImpl()) { self.repository = repository }
    
    func execute(relationId: String, isAccepted: Bool) async throws {
        try await repository.respondToRequest(relationId: relationId, isAccepted: isAccepted)
    }
}
