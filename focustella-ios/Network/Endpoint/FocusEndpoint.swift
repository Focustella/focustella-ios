import Foundation

enum FocusEndpoint: Endpoint {
    case create(durationMinutes: Int)
    case save(FocusSessionSaveRequestDTO)
    case list

    var path: String {
        switch self {
        case .create:
            return "session/focus/create"
        case .save, .list:
            return "session/focus"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .create, .list:
            return .get
        case .save:
            return .post
        }
    }

    var requiresAuth: Bool { true }

    var body: Encodable? {
        switch self {
        case .create, .list:
            return nil
        case let .save(request):
            return request
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case let .create(durationMinutes):
            return [URLQueryItem(name: "durationMinutes", value: String(durationMinutes))]
        case .save, .list:
            return []
        }
    }
}
