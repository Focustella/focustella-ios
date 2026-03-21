import Foundation

protocol Endpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var requiresAuth: Bool { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem] { get }
    var body: Encodable? { get }
}

extension Endpoint {
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }
    var body: Encodable? { nil }
}
