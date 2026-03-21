import Foundation

struct ConstellationDTO: Decodable, Encodable {
    let id: Int
    let name: String
    let createdBy: String?
    let starCount: Int
    let defaultScale: Double
    let minScale: Double
    let maxScale: Double
    let createdAt: String
    let updatedAt: String
    let stars: [ConstellationStarDTO]
    let edges: [ConstellationEdgeDTO]
}

struct ConstellationStarDTO: Decodable, Encodable {
    let id: Int
    let vectorX: Double
    let vectorY: Double
}

struct ConstellationEdgeDTO: Decodable, Encodable {
    let id: Int
    let fromStarId: Int
    let toStarId: Int
}
