import Foundation

protocol FriendRepository {
    func fetchFriends(userId: String) async throws -> (friends: [Friend], pendingRequests: [FriendRequest])
    func sendRequest(requesterId: String, receiverId: String) async throws
    func respondToRequest(relationId: String, isAccepted: Bool) async throws
}
