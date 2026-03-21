import SwiftUI

struct ServerConstellationPayload: Identifiable, Hashable {
    let id: String
    let name: String
    let visualStyle: ConstellationVisualStyle
    let representativePoint: ServerPoint
    let stars: [ServerRelativeStar]
    let edges: [ServerEdge]
    let serverId: Int?
}

struct ServerPoint: Hashable {
    let x: Double
    let y: Double
}

struct ServerRelativeStar: Identifiable, Hashable {
    let id: String
    let dx: Double
    let dy: Double
}

struct ServerEdge: Hashable {
    let fromId: String
    let toId: String
}
