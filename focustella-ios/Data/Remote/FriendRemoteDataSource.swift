import Foundation

protocol FriendRemoteDataSource {
    func fetchFriends(userId: String) async throws -> [FriendRelationDTO]
    func sendRequest(requesterId: String, receiverId: String) async throws -> FriendRelationDTO
    func respondToRequest(relationId: String, isAccepted: Bool) async throws -> EmptyData
}

final class FriendRemoteDataSourceImpl: FriendRemoteDataSource {
    private let apiClient = APIClient.shared

    func fetchFriends(userId: String) async throws -> [FriendRelationDTO] {
        let endpoint = FriendEndpoint.fetchFriends(userId: userId)
        return try await apiClient.send(endpoint: endpoint)
    }

    func sendRequest(requesterId: String, receiverId: String) async throws -> FriendRelationDTO {
        let body = FriendRequestBody(requesterId: requesterId, receiverId: receiverId)
        let endpoint = FriendEndpoint.sendRequest(body: body)
        return try await apiClient.send(endpoint: endpoint)
    }

    func respondToRequest(relationId: String, isAccepted: Bool) async throws -> EmptyData {
        let body = FriendAcceptBody(relationId: relationId, accept: isAccepted)
        let endpoint = FriendEndpoint.acceptRequest(body: body)
        return try await apiClient.send(endpoint: endpoint)
    }
}
