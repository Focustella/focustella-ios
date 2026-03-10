import SwiftUI

enum ConstellationVisualStyle: String, Hashable {
    case skyBlue
    case debugRed
}

struct Constellation: Identifiable, Hashable {
    let id: UUID
    let name: String
    let starCount: Int
    let representativePoint: CGPoint
    let visualStyle: ConstellationVisualStyle
    let stars: [Star]
    let edges: [Edge]

    init(
        id: UUID = UUID(),
        name: String,
        representativePoint: CGPoint? = nil,
        visualStyle: ConstellationVisualStyle = .skyBlue,
        stars: [Star],
        edges: [Edge]
    ) {
        self.id = id
        self.name = name
        self.starCount = stars.count
        self.visualStyle = visualStyle
        if let representativePoint {
            self.representativePoint = representativePoint
        } else if stars.isEmpty {
            self.representativePoint = CGPoint(x: 0.5, y: 0.5)
        } else {
            let cx = stars.map(\.x).reduce(0, +) / CGFloat(stars.count)
            let cy = stars.map(\.y).reduce(0, +) / CGFloat(stars.count)
            self.representativePoint = CGPoint(x: cx, y: cy)
        }
        self.stars = stars
        self.edges = edges
    }
}

struct Star: Identifiable, Hashable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat

    init(id: UUID = UUID(), x: CGFloat, y: CGFloat) {
        self.id = id
        self.x = x
        self.y = y
    }
}

struct Edge: Hashable {
    let from: UUID
    let to: UUID
}
