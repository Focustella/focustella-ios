import Foundation
import CoreGraphics

struct Constellation: Identifiable, Hashable {
    let id: UUID
    let name: String
    let anchor: CGPoint
    let stars: [StarObject]
    let edges: [ConstellationEdge]

    init(
        id: UUID = UUID(),
        name: String,
        anchor: CGPoint,
        stars: [StarObject],
        edges: [ConstellationEdge]
    ) {
        self.id = id
        self.name = name
        self.anchor = anchor
        self.stars = stars
        self.edges = edges
    }
}

struct ConstellationEdge: Hashable {
    let fromID: UUID
    let toID: UUID

    init(fromID: UUID, toID: UUID) {
        self.fromID = fromID
        self.toID = toID
    }
}
