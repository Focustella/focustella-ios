import Foundation

enum APIClientError: LocalizedError {
    case invalidBaseURL
    case missingAuthToken
    case invalidResponse
    case server(statusCode: Int, code: String?, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "API base URL이 올바르지 않습니다."
        case .missingAuthToken:
            return "인증 토큰이 없습니다."
        case .invalidResponse:
            return "응답 형식이 올바르지 않습니다."
        case let .server(statusCode, code, message):
            if let message, !message.isEmpty {
                return "[\(statusCode)] \(message)"
            }
            if let code, !code.isEmpty {
                return "[\(statusCode)] \(code)"
            }
            return "[\(statusCode)] 서버 요청에 실패했습니다."
        }
    }
}
