import CoreGraphics

struct ConstellationGeometry {
    let constellation: Constellation

    var normalizedPoints: [CGPoint] {
        constellation.stars.map { CGPoint(x: $0.x, y: $0.y) }
    }

    var normalizedBounds: CGRect {
        guard let first = normalizedPoints.first else { return .null }

        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y

        for point in normalizedPoints.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    var visualFocusPoint: CGPoint {
        let bounds = normalizedBounds
        guard !bounds.isNull else { return constellation.representativePoint }
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
}
