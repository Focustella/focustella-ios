import Foundation

enum SkyEndpoint: Endpoint {
    case me
    case user(String)

    var path: String {
        switch self {
        case .me:
            return "sky/me"
        case let .user(id):
            return "sky/\(id)"
        }
    }

    var method: HTTPMethod { .get }

    var requiresAuth: Bool {
        switch self {
        case .me:
            return true
        case .user:
            return false
        }
    }
}
