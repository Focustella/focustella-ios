// 📂 Network/Endpoint/UserEndpoint.swift
import Foundation

enum UserEndpoint: Endpoint {
    case search(String)

    var path: String {
        switch self {
        case .search:
            return "users" // 🔥 ?keyword=... 부분을 완전히 지웁니다!
        }
    }

    var method: HTTPMethod { .get }
    
    var requiresAuth: Bool { true }

    // 🔥 여기서 URLQueryItem으로 안전하게 파라미터를 넘겨줍니다!
    var queryItems: [URLQueryItem] {
        switch self {
        case let .search(keyword):
            // 애플의 순정 기능이 알아서 안전하게 인코딩과 ? 기호를 처리해 줍니다.
            return [URLQueryItem(name: "keyword", value: keyword)]
        }
    }
}
