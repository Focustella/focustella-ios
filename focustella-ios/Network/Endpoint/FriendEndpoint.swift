import Foundation

enum FriendEndpoint: Endpoint {
    case fetchFriends(userId: String)
    case sendRequest(body: FriendRequestBody)
    case acceptRequest(body: FriendAcceptBody)

    var path: String {
        switch self {
        case .fetchFriends: return "friend"
        case .sendRequest: return "friend/request"
        case .acceptRequest: return "friend/accept"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .fetchFriends: return .get
        case .sendRequest, .acceptRequest: return .post
        }
    }

    var requiresAuth: Bool { return true }

    var queryItems: [URLQueryItem] {
        switch self {
        case .fetchFriends(let userId): return [URLQueryItem(name: "userId", value: userId)]
        default: return []
        }
    }

    var body: Encodable? {
        switch self {
        case .fetchFriends: return nil
        case .sendRequest(let body): return body
        case .acceptRequest(let body): return body
        }
    }
}
