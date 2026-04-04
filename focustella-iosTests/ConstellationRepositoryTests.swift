import XCTest
import CoreGraphics
@testable import focustella_ios

final class ConstellationRepositoryTests: XCTestCase {
    func testPlaceRemoteConstellationReturnsNilWhenOccupiedSkyAlreadyBlocksPlacement() {
        let repository = ConstellationRepository(service: MockConstellationService())
        let occupied = blockingConstellation()

        let placed = repository.placeRemoteConstellation(
            template: compactTemplate(id: 101),
            placementKey: "session-101",
            occupied: [occupied],
            randomSeed: 42
        )

        XCTAssertNil(placed)
    }

    func testPlaceRemoteConstellationSpreadsRepeatedPlacementsWithoutOverlap() {
        let repository = ConstellationRepository(service: MockConstellationService())
        let template = compactTemplate(id: 7)
        var placed: [Constellation] = []

        for index in 0..<4 {
            let constellation = repository.placeRemoteConstellation(
                template: template,
                placementKey: "session-\(index)",
                occupied: placed,
                randomSeed: 777
            )

            XCTAssertNotNil(constellation, "Expected placement to succeed for repeated session \(index)")
            if let constellation {
                placed.append(constellation)
            }
        }

        XCTAssertFalse(hasOverlap(in: placed))
    }

    private func compactTemplate(id: Int) -> ConstellationDTO {
        ConstellationPlacementFixture.compactTemplate(id: id)
    }

    private func blockingConstellation() -> Constellation {
        ConstellationPlacementFixture.blockingConstellation()
    }

    private func hasOverlap(in constellations: [Constellation]) -> Bool {
        for i in 0..<constellations.count {
            for j in (i + 1)..<constellations.count {
                if polygonsOverlap(hull(for: constellations[i]), hull(for: constellations[j])) {
                    return true
                }
            }
        }
        return false
    }

    private func hull(for constellation: Constellation) -> [CGPoint] {
        convexHull(constellation.stars.map { CGPoint(x: $0.x, y: $0.y) })
    }

    private func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted {
            if $0.x == $1.x { return $0.y < $1.y }
            return $0.x < $1.x
        }

        guard sorted.count > 2 else { return sorted }

        var lower: [CGPoint] = []
        for point in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 {
                lower.removeLast()
            }
            lower.append(point)
        }

        var upper: [CGPoint] = []
        for point in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 {
                upper.removeLast()
            }
            upper.append(point)
        }

        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    private func polygonsOverlap(_ lhs: [CGPoint], _ rhs: [CGPoint]) -> Bool {
        guard lhs.count >= 3, rhs.count >= 3 else { return false }

        for edgeA in polygonEdges(lhs) {
            for edgeB in polygonEdges(rhs) {
                if segmentsIntersect(edgeA.0, edgeA.1, edgeB.0, edgeB.1) {
                    return true
                }
            }
        }

        return pointInPolygon(lhs[0], polygon: rhs) || pointInPolygon(rhs[0], polygon: lhs)
    }

    private func polygonEdges(_ polygon: [CGPoint]) -> [(CGPoint, CGPoint)] {
        polygon.indices.map { index in
            let next = (index + 1) % polygon.count
            return (polygon[index], polygon[next])
        }
    }

    private func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint, _ q1: CGPoint, _ q2: CGPoint) -> Bool {
        let o1 = orientation(p1, p2, q1)
        let o2 = orientation(p1, p2, q2)
        let o3 = orientation(q1, q2, p1)
        let o4 = orientation(q1, q2, p2)

        if o1 != o2 && o3 != o4 { return true }
        if o1 == 0 && onSegment(p1, q1, p2) { return true }
        if o2 == 0 && onSegment(p1, q2, p2) { return true }
        if o3 == 0 && onSegment(q1, p1, q2) { return true }
        if o4 == 0 && onSegment(q1, p2, q2) { return true }
        return false
    }

    private func orientation(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Int {
        let value = (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y)
        if abs(value) < 0.000001 { return 0 }
        return value > 0 ? 1 : 2
    }

    private func onSegment(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Bool {
        b.x <= max(a.x, c.x) + 0.000001 &&
        b.x + 0.000001 >= min(a.x, c.x) &&
        b.y <= max(a.y, c.y) + 0.000001 &&
        b.y + 0.000001 >= min(a.y, c.y)
    }

    private func pointInPolygon(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
        var inside = false
        var previousIndex = polygon.count - 1

        for index in polygon.indices {
            let current = polygon[index]
            let previous = polygon[previousIndex]
            let intersects = ((current.y > point.y) != (previous.y > point.y)) &&
                (point.x < (previous.x - current.x) * (point.y - current.y) / ((previous.y - current.y) + 0.000001) + current.x)
            if intersects {
                inside.toggle()
            }
            previousIndex = index
        }

        return inside
    }

    private func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }
}
