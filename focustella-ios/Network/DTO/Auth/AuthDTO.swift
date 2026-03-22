import Foundation

// 1. 요청 바디
struct SignInRequestBody: Encodable {
    let email: String
}

struct UpdateNicknameBody: Encodable {
    let nickname: String
}

// 2. 서버에서 받는 유저 정보
struct UserDTO: Decodable {
    let id: String
    let userCode: String
    let nickname: String? // 🔥 핵심! 튜토리얼 분기점 (nil이면 튜토리얼 시작)
    let email: String?
    let seed: Int
    let type: String
    let createdAt: String
    let updatedAt: String?
}

// 3. 통합 로그인 응답
struct AuthResponseDTO: Decodable {
    let accessToken: String
    let user: UserDTO
}
