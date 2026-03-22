import Foundation

// 🔥 불필요한 껍데기(success, data 등)를 싹 지우고 이것만 남깁니다!
struct UserSearchDTO: Decodable {
    let id: String
    let nickname: String
    let userCode: String
}
