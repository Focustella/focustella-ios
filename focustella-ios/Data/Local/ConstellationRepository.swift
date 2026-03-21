import SwiftUI

final class ConstellationRepository {
    private static let sharedService = MockConstellationService()
    private let service: MockConstellationService

    init(service: MockConstellationService = ConstellationRepository.sharedService) {
        self.service = service
    }

    func fetchSessionConstellation(durationSeconds: Int, occupied: [Constellation], userId: String) async -> Constellation? {
        let payloads = await service.fetchConstellationCandidates(durationSeconds: durationSeconds, userId: userId)
        for payload in payloads {
            if let constellation = place(payload: payload, occupied: occupied) {
                return constellation
            }
        }
        return nil
    }

    func fetchUserConstellations(userId: String, occupied: [Constellation]) async -> [Constellation] {
        let payloads = await service.fetchConstellationsForUser(userId: userId)
        var placed: [Constellation] = []
        var occupiedAll = occupied
        for payload in payloads {
            if let constellation = place(payload: payload, occupied: occupiedAll) {
                placed.append(constellation)
                occupiedAll.append(constellation)
            }
        }
        return placed
    }

    func fetchCustomConstellations(userId: String, occupied: [Constellation]) async -> [Constellation] {
        let payloads = await service.fetchCustomConstellationsForUser(userId: userId)
        var placed: [Constellation] = []
        var occupiedAll = occupied

        for payload in payloads {
            let constellation = place(payload: payload, occupied: occupiedAll) ?? place(payload: payload, occupied: [])
            guard let constellation else { continue }
            placed.append(constellation)
            occupiedAll.append(constellation)
        }

        return placed
    }

    func fetchInitialPreviewConstellations(occupied: [Constellation], limit: Int = 3) async -> [Constellation] {
        let payloads = await service.fetchBasePreviewConstellations(limit: limit)
        var placed: [Constellation] = []
        var occupiedAll = occupied
        for payload in payloads {
            if let constellation = place(payload: payload, occupied: occupiedAll) {
                placed.append(constellation)
                occupiedAll.append(constellation)
            }
        }
        return placed
    }

    func fetchInsertedUserConstellation(id: String, userId: String, occupied: [Constellation]) async -> Constellation? {
        guard let payload = await service.fetchCustomConstellation(id: id, userId: userId) else {
            return nil
        }
        return place(payload: payload, occupied: occupied) ?? place(payload: payload, occupied: [])
    }

    func placeRemoteConstellation(
        template: ConstellationDTO,
        placementKey: String,
        occupied: [Constellation]
    ) -> Constellation? {
        let payload = ServerConstellationPayload(
            id: "remote-\(placementKey)-\(template.id)",
            name: template.name,
            visualStyle: .skyBlue,
            representativePoint: ServerPoint(x: 0, y: 0),
            stars: template.stars.map {
                ServerRelativeStar(
                    id: "s\($0.id)",
                    dx: $0.vectorX,
                    dy: $0.vectorY
                )
            },
            edges: template.edges.map { ServerEdge(fromId: "s\($0.fromStarId)", toId: "s\($0.toStarId)") },
            serverId: template.id
        )

        return place(payload: payload, occupied: occupied) ?? place(payload: payload, occupied: [])
    }

    func insertUserConstellation(
        userId: String,
        name: String,
        relativeStars: [CGPoint],
        edges: [(Int, Int)],
        visualStyle: ConstellationVisualStyle = .skyBlue
    ) async -> String? {
        guard relativeStars.count >= 3 else { return nil }

        let center = CGPoint(
            x: relativeStars.map(\.x).reduce(0, +) / CGFloat(relativeStars.count),
            y: relativeStars.map(\.y).reduce(0, +) / CGFloat(relativeStars.count)
        )
        let centered = relativeStars.map { CGPoint(x: $0.x - center.x, y: $0.y - center.y) }

        // Dev canvas allows drawing close to the full preview bounds, which is too large for the
        // sky placement rules. Shrink only when needed so custom constellations still preserve the
        // user's shape but can be placed inside the visible sky.
        let maxExtent = max(
            centered.map { max(abs($0.x), abs($0.y)) }.max() ?? 0,
            0.0001
        )
        let placementExtentLimit: CGFloat = 0.18
        let placementScale = min(1, placementExtentLimit / maxExtent)
        let normalized = centered.map { CGPoint(x: $0.x * placementScale, y: $0.y * placementScale) }

        let stars = normalized.enumerated().map { index, p in
            ServerRelativeStar(
                id: "u\(index)",
                dx: p.x,
                dy: p.y
            )
        }
        let serverEdges: [ServerEdge] = edges.compactMap { from, to in
            guard from >= 0, to >= 0, from < stars.count, to < stars.count, from != to else { return nil }
            return ServerEdge(fromId: "u\(from)", toId: "u\(to)")
        }

        let payload = ServerConstellationPayload(
            id: "custom-\(UUID().uuidString.lowercased())",
            name: name,
            visualStyle: visualStyle,
            representativePoint: ServerPoint(x: 0, y: 0),
            stars: stars,
            edges: serverEdges,
            serverId: nil
        )
        await service.insertConstellation(payload, for: userId)
        return payload.id
    }

    private func place(payload: ServerConstellationPayload, occupied: [Constellation]) -> Constellation? {
        let existingMeta = occupied.map { constellation in
            let points = constellation.stars.map { CGPoint(x: $0.x, y: $0.y) }
            let rep = constellation.representativePoint
            let radius = (points.map { hypot($0.x - rep.x, $0.y - rep.y) }.max() ?? 0) + 0.035
            return OccupiedConstellation(rep: rep, radius: radius, hull: paddedHull(convexHull(points), padding: 0.02))
        }

        var rng = SeededGenerator(seed: UInt64(abs(payload.id.hashValue)) + 991)
        let baseAngle = rng.nextCGFloat(in: 0...(CGFloat.pi * 2))
        let baseRadius = rng.nextCGFloat(in: 0.12...0.42)
        let radiusSpread = rng.nextCGFloat(in: 0.08...0.18)
        let angleJitter = rng.nextCGFloat(in: -0.32...0.32)
        let aspectBias = rng.nextCGFloat(in: 0.82...1.08)

        for attempt in 0..<520 {
            let t = CGFloat(attempt) / 520
            let angle = baseAngle + angleJitter + CGFloat(attempt) * 2.399963
            let radius = min(0.46, baseRadius + t * radiusSpread)
            let center = CGPoint(
                x: 0.5 + cos(angle) * radius,
                y: 0.5 + sin(angle) * radius * aspectBias
            )
            let rotation = payload.id.hasPrefix("custom-") ? 0 : rng.nextCGFloat(in: (-.pi)...(.pi))

            let transformed = transform(payload: payload, center: center, rotation: rotation)
            let points = transformed.points
            let rep = transformed.representative

            guard isInsideBounds(points) else { continue }

            let collisionRadius = (points.map { hypot($0.x - rep.x, $0.y - rep.y) }.max() ?? 0) + 0.035
            if existingMeta.contains(where: { hypot($0.rep.x - rep.x, $0.rep.y - rep.y) < ($0.radius + collisionRadius) }) {
                continue
            }

            let hull = paddedHull(convexHull(points), padding: 0.02)
            if existingMeta.contains(where: { hullsOverlap(hull, $0.hull) }) {
                continue
            }

            let stars = transformed.stars
            let idMap = Dictionary(
                uniqueKeysWithValues: zip(payload.stars.map { $0.id.lowercased() }, stars.map { $0.id })
            )
            let edges: [Edge] = payload.edges.compactMap { (edge: ServerEdge) -> Edge? in
                guard let from = idMap[edge.fromId.lowercased()], let to = idMap[edge.toId.lowercased()] else { return nil }
                return Edge(from: from, to: to)
            }

            return Constellation(
                id: UUID(uuidString: deterministicUUIDString(input: payload.id)) ?? UUID(),
                serverId: payload.serverId,
                name: payload.name,
                representativePoint: rep,
                visualStyle: payload.visualStyle,
                stars: stars,
                edges: edges
            )
        }

        return nil
    }

    private func transform(payload: ServerConstellationPayload, center: CGPoint, rotation: CGFloat) -> (stars: [Star], points: [CGPoint], representative: CGPoint) {
        let c = cos(rotation)
        let s = sin(rotation)

        // Placement center is the absolute representative point for this user's sky.
        let representative = center

        var stars: [Star] = []
        var points: [CGPoint] = []
        stars.reserveCapacity(payload.stars.count)
        points.reserveCapacity(payload.stars.count)

        for serverStar in payload.stars {
            let rv = CGPoint(x: serverStar.dx, y: serverStar.dy)
            let rotatedVector = CGPoint(
                x: rv.x * c - rv.y * s,
                y: rv.x * s + rv.y * c
            )
            let absolute = CGPoint(x: representative.x + rotatedVector.x, y: representative.y + rotatedVector.y)

            // deterministic UUID by server star id
            let starUUID = UUID(uuidString: deterministicUUIDString(input: "\(payload.id)|\(serverStar.id)")) ?? UUID()
            stars.append(Star(id: starUUID, x: absolute.x, y: absolute.y))
            points.append(absolute)
        }

        return (stars, points, representative)
    }

    private func deterministicUUIDString(input: String) -> String {
        let hash = abs(input.hashValue)
        let hex = String(format: "%032x", hash)
        return "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
    }

    private func isInsideBounds(_ points: [CGPoint]) -> Bool {
        points.allSatisfy { (0.04...0.96).contains($0.x) && (0.04...0.96).contains($0.y) }
    }

    private func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted {
            if $0.x == $1.x { return $0.y < $1.y }
            return $0.x < $1.x
        }
        guard sorted.count > 2 else { return sorted }

        var lower: [CGPoint] = []
        for p in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }

        var upper: [CGPoint] = []
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }

        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    private func paddedHull(_ hull: [CGPoint], padding: CGFloat) -> [CGPoint] {
        guard hull.count >= 3 else { return hull }
        let center = CGPoint(
            x: hull.map(\.x).reduce(0, +) / CGFloat(hull.count),
            y: hull.map(\.y).reduce(0, +) / CGFloat(hull.count)
        )

        return hull.map { point in
            let vx = point.x - center.x
            let vy = point.y - center.y
            let len = max(0.0001, hypot(vx, vy))
            return CGPoint(x: point.x + (vx / len) * padding, y: point.y + (vy / len) * padding)
        }
    }

    private func hullsOverlap(_ a: [CGPoint], _ b: [CGPoint]) -> Bool {
        guard a.count >= 3, b.count >= 3 else { return false }

        for ea in polygonEdges(a) {
            for eb in polygonEdges(b) {
                if segmentsIntersect(ea.0, ea.1, eb.0, eb.1) {
                    return true
                }
            }
        }

        return pointInPolygon(a[0], polygon: b) || pointInPolygon(b[0], polygon: a)
    }

    private func polygonEdges(_ polygon: [CGPoint]) -> [(CGPoint, CGPoint)] {
        polygon.indices.map { i in
            let next = (i + 1) % polygon.count
            return (polygon[i], polygon[next])
        }
    }

    private func pointInPolygon(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1

        for i in polygon.indices {
            let pi = polygon[i]
            let pj = polygon[j]
            let intersects = ((pi.y > point.y) != (pj.y > point.y)) &&
                (point.x < (pj.x - pi.x) * (point.y - pi.y) / ((pj.y - pi.y) + 0.000001) + pi.x)
            if intersects {
                inside.toggle()
            }
            j = i
        }
        return inside
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

    private func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }
}

private struct OccupiedConstellation {
    let rep: CGPoint
    let radius: CGFloat
    let hull: [CGPoint]
}

private struct SeededGenerator: Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E37 : seed
    }

    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }

    mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let ratio = Double(next() & 0xFFFF_FFFF) / Double(UInt32.max)
        return range.lowerBound + CGFloat(ratio) * (range.upperBound - range.lowerBound)
    }
}
