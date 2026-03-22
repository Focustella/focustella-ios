import Foundation

enum AuthEndpoint: Endpoint {
    case anonymous
    case signIn(email: String)
    case updateNickname(nickname: String)

    var path: String {
        switch self {
        case .anonymous: return "auth/anonymous"
        case .signIn: return "auth/signin"
        case .updateNickname: return "auth/nickname"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .anonymous, .signIn: return .post
        case .updateNickname: return .patch // 🔥 닉네임은 PATCH
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .anonymous, .signIn: return false
        case .updateNickname: return true // 닉네임 변경은 토큰 필요!
        }
    }
    
    var body: Encodable? {
        switch self {
        case .anonymous: return nil
        case .signIn(let email): return SignInRequestBody(email: email)
        case .updateNickname(let nickname): return UpdateNicknameBody(nickname: nickname)
        }
    }
}
