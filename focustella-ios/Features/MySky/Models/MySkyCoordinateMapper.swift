import SwiftUI

struct MySkyCoordinateMapper: Hashable {
    let canvasSize: CGSize

    func worldPoint(fromNormalized point: CGPoint) -> CGPoint {
        let side = min(canvasSize.width, canvasSize.height)
        let origin = CGPoint(
            x: (canvasSize.width - side) / 2,
            y: (canvasSize.height - side) / 2
        )
        return CGPoint(
            x: origin.x + point.x * side,
            y: origin.y + point.y * side
        )
    }

    func normalizedPoint(fromWorld world: CGPoint) -> CGPoint {
        let side = max(1, min(canvasSize.width, canvasSize.height))
        let origin = CGPoint(
            x: (canvasSize.width - side) / 2,
            y: (canvasSize.height - side) / 2
        )
        return CGPoint(
            x: (world.x - origin.x) / side,
            y: (world.y - origin.y) / side
        )
    }

    func worldPoint(for star: Star) -> CGPoint {
        worldPoint(fromNormalized: CGPoint(x: star.x, y: star.y))
    }
}
