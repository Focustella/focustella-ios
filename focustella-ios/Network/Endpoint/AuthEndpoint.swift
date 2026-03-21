import Foundation

enum AuthEndpoint: Endpoint {
    case anonymous

    var path: String {
        switch self {
        case .anonymous:
            return "auth/anonymous"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .anonymous:
            return .post
        }
    }

    var requiresAuth: Bool { false }
}
