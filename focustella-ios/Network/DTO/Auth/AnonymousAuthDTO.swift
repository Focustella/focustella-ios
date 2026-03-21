import Foundation

struct AnonymousAuthData: Decodable {
    let accessToken: String
    let user: AnonymousUser
}

struct AnonymousUser: Decodable {
    let id: String
    let seed: Int64
    let type: String
    let createdAt: String
}
