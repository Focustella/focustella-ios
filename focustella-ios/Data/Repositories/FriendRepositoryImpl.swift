import Foundation

// 🔥 FriendRepositoryInterface -> FriendRepository 로 변경
final class FriendRepositoryImpl: FriendRepository {
    private let remoteDataSource: FriendRemoteDataSource

    init(remoteDataSource: FriendRemoteDataSource = FriendRemoteDataSourceImpl()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchFriends(userId: String) async throws -> (friends: [Friend], pendingRequests: [FriendRequest]) {
        let dtos = try await remoteDataSource.fetchFriends(userId: userId)
        
        let friends = dtos
            .filter { $0.status == "ACCEPTED" }
            .map { dto in
                let otherId = dto.requesterId == userId ? dto.receiverId : dto.requesterId
                return Friend(id: otherId, name: otherId)
            }
            
        let requests = dtos
            .filter { $0.status == "PENDING" && $0.receiverId == userId }
            .map { dto in
                FriendRequest(id: dto.id, senderName: dto.requesterId)
            }
            
        return (friends, requests)
    }

    func sendRequest(requesterId: String, receiverId: String) async throws {
        _ = try await remoteDataSource.sendRequest(requesterId: requesterId, receiverId: receiverId)
    }

    func respondToRequest(relationId: String, isAccepted: Bool) async throws {
        _ = try await remoteDataSource.respondToRequest(relationId: relationId, isAccepted: isAccepted)
    }
}
