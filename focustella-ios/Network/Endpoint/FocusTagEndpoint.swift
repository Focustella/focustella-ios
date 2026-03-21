import Foundation

enum FocusTagEndpoint: Endpoint {
    case list
    case add(UserTagMutationRequestDTO)
    case delete(UserTagMutationRequestDTO)

    var path: String {
        switch self {
        case .list:
            return "session/focus/tag"
        case .add:
            return "session/focus/tag/add"
        case .delete:
            return "session/focus/tag/delete"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list:
            return .get
        case .add:
            return .post
        case .delete:
            return .delete
        }
    }

    var requiresAuth: Bool { true }

    var body: Encodable? {
        switch self {
        case .list:
            return nil
        case let .add(request), let .delete(request):
            return request
        }
    }
}
