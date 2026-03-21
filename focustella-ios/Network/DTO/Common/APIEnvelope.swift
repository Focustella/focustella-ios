import Foundation

struct APIErrorDetailPayload: Decodable {
    let field: String?
    let rejectedValue: String?
    let reason: String?
}

struct APIErrorPayload: Decodable {
    let code: String?
    let message: String?
    let path: String?
    let details: [APIErrorDetailPayload]?
}

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: APIErrorPayload?
    let timestamp: String?
}

struct EmptyAPIResponse: Decodable {}
