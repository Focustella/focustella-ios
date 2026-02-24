import Foundation
import CoreGraphics

struct StarObject: Identifiable, Hashable {
    let id: UUID
    let position: CGPoint
    let color: StarColor

    init(id: UUID = UUID(), position: CGPoint, color: StarColor = .warmYellow) {
        self.id = id
        self.position = position
        self.color = color
    }
}

enum StarColor: String, Hashable {
    case warmYellow
    case paleBlue
}
