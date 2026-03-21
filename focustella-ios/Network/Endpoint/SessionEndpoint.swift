import Foundation

enum SessionEndpoint: Endpoint {
    case saveDaily(DailySessionSaveRequest)
    case fetchDailyList

    var path: String {
        switch self {
        case .saveDaily, .fetchDailyList:
            return "session/daily"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .saveDaily:
            return .post
        case .fetchDailyList:
            return .get
        }
    }

    var requiresAuth: Bool { true }

    var body: Encodable? {
        switch self {
        case let .saveDaily(request):
            return request
        case .fetchDailyList:
            return nil
        }
    }
}
