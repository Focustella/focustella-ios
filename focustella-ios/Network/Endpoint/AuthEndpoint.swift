import Foundation

enum AuthEndpoint: Endpoint {
    case anonymous
    case signIn(email: String)
    case updateNickname(nickname: String)
    case deleteAccount // 🔥 1. 회원 탈퇴 케이스 추가!

    var path: String {
        switch self {
        case .anonymous: return "auth/anonymous"
        case .signIn: return "auth/signin"
        case .updateNickname: return "auth/nickname"
        case .deleteAccount: return "auth/delete" // 🔥 2. 백엔드 탈퇴 URL 연결
        }
    }

    var method: HTTPMethod {
        switch self {
        case .anonymous, .signIn: return .post
        case .updateNickname: return .patch
        case .deleteAccount: return .delete // 🔥 3. HTTP 메서드는 DELETE!
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .anonymous, .signIn: return false
        case .updateNickname, .deleteAccount: return true // 🔥 4. 탈퇴도 당연히 토큰(로그인) 필요!
        }
    }
    
    var body: Encodable? {
        switch self {
        case .anonymous: return nil
        case .signIn(let email): return SignInRequestBody(email: email)
        case .updateNickname(let nickname): return UpdateNicknameBody(nickname: nickname)
        case .deleteAccount: return nil // 🔥 5. 탈퇴 요청에는 바디(데이터)가 필요 없습니다.
        }
    }
}
