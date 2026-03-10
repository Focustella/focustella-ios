import SwiftUI

struct ServerConstellationPayload: Identifiable, Hashable {
    let id: String
    let name: String
    let visualStyle: ConstellationVisualStyle
    let representativePoint: ServerPoint
    let stars: [ServerRelativeStar]
    let edges: [ServerEdge]
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

final class ConstellationRepository {
    private static let customTargetRadius: CGFloat = 0.16
    private static let sharedService = MockConstellationService()
    private let service: MockConstellationService

    init(service: MockConstellationService = ConstellationRepository.sharedService) {
        self.service = service
    }

    func fetchSessionConstellation(durationSeconds: Int, occupied: [Constellation], userId: String) async -> Constellation? {
        guard let payload = await service.fetchConstellation(durationSeconds: durationSeconds, userId: userId) else {
            return nil
        }
        return place(payload: payload, occupied: occupied)
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

    func insertUserConstellation(
        userId: String,
        name: String,
        relativeStars: [CGPoint],
        edges: [(Int, Int)],
        visualStyle: ConstellationVisualStyle = .skyBlue
    ) async {
        guard relativeStars.count >= 3 else { return }

        let center = CGPoint(
            x: relativeStars.map(\.x).reduce(0, +) / CGFloat(relativeStars.count),
            y: relativeStars.map(\.y).reduce(0, +) / CGFloat(relativeStars.count)
        )
        let centered = relativeStars.map { CGPoint(x: $0.x - center.x, y: $0.y - center.y) }
        let maxRadius = centered.map { hypot($0.x, $0.y) }.max() ?? 0
        let scale = maxRadius > 0 ? min(1.0, ConstellationRepository.customTargetRadius / maxRadius) : 1.0

        let stars = centered.enumerated().map { index, p in
            ServerRelativeStar(
                id: "u\(index)",
                dx: p.x * scale,
                dy: p.y * scale
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
            edges: serverEdges
        )
        await service.insertConstellation(payload, for: userId)
    }

    private func place(payload: ServerConstellationPayload, occupied: [Constellation]) -> Constellation? {
        let existingMeta = occupied.map { constellation in
            let points = constellation.stars.map { CGPoint(x: $0.x, y: $0.y) }
            let rep = constellation.representativePoint
            let radius = (points.map { hypot($0.x - rep.x, $0.y - rep.y) }.max() ?? 0) + 0.035
            return OccupiedConstellation(rep: rep, radius: radius, hull: paddedHull(convexHull(points), padding: 0.02))
        }

        var rng = SeededGenerator(seed: UInt64(abs(payload.id.hashValue)) + 991)

        for attempt in 0..<520 {
            let t = CGFloat(attempt) / 520
            let angle = CGFloat(attempt) * 2.399963 + rng.nextCGFloat(in: -0.12...0.12)
            let radius = 0.1 + t * 0.4
            let center = CGPoint(x: 0.5 + cos(angle) * radius, y: 0.5 + sin(angle) * radius * 0.9)
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

actor MockConstellationService {
    private let basePayloads: [ServerConstellationPayload]
    private var customPayloadsByUser: [String: [ServerConstellationPayload]] = [:]

    init() {
        self.basePayloads = MockConstellationService.makePayloads()
    }

    func fetchConstellation(durationSeconds: Int, userId: String) async -> ServerConstellationPayload? {
        try? await Task.sleep(for: .milliseconds(240))
        let payloads = allPayloads(for: userId)

        let range: ClosedRange<Int>
        switch durationSeconds {
        case ..<3600: range = 5...7
        case 3600..<7200: range = 8...10
        case 7200..<10800: range = 11...20
        default: range = 21...40
        }

        let inRange = payloads.filter { range.contains($0.stars.count) }
        if let selected = inRange.randomElement() {
            return selected
        }
        return payloads.randomElement()
    }

    func fetchConstellationsForUser(userId: String) async -> [ServerConstellationPayload] {
        try? await Task.sleep(for: .milliseconds(220))
        let custom = customPayloadsByUser[userId] ?? []
        var shuffledBase = basePayloads

        var state = UInt64(abs(userId.hashValue))
        func next(_ state: inout UInt64) -> UInt64 {
            state = 6364136223846793005 &* state &+ 1442695040888963407
            return state
        }

        for i in shuffledBase.indices.reversed() where i > 0 {
            let j = Int(next(&state) % UInt64(i + 1))
            if i != j {
                shuffledBase.swapAt(i, j)
            }
        }

        // Always prioritize user-created constellations in MySky preview.
        let baseTake = max(0, 3 - custom.count)
        return custom + Array(shuffledBase.prefix(baseTake))
    }

    func insertConstellation(_ payload: ServerConstellationPayload, for userId: String) {
        var list = customPayloadsByUser[userId] ?? []
        list.insert(payload, at: 0)
        customPayloadsByUser[userId] = list
    }

    private func allPayloads(for userId: String) -> [ServerConstellationPayload] {
        let custom = customPayloadsByUser[userId] ?? []
        return custom + basePayloads
    }

    private static func makePayloads() -> [ServerConstellationPayload] {
        var items: [ServerConstellationPayload] = []

        items.append(bigDipperPayload())

        let specs: [(String, Int, UInt64)] = [
            ("Lumen Arc", 5, 41),
            ("Iris Gate", 6, 87),
            ("Drift Swan", 7, 119),
            ("North Veil", 8, 204),
            ("Aurora Fork", 9, 255),
            ("Glass Harbor", 10, 318),
            ("Echo Path", 11, 390),
            ("Silver Bloom", 13, 512),
            ("Quiet Engine", 15, 621),
            ("Ocean Bridge", 18, 744),
            ("Winter Crown", 24, 888),
            ("Atlas River", 30, 978)
        ]

        for (name, starCount, seed) in specs {
            let points = makeTemplatePoints(starCount: starCount, seed: seed)
            let representative = representativePoint(from: points)
            let stars = points.enumerated().map { index, p in
                ServerRelativeStar(
                    id: "s\(index)",
                    dx: p.x - representative.x,
                    dy: p.y - representative.y
                )
            }
            let edges = makeTemplateEdges(starCount: starCount).map { ServerEdge(fromId: "s\($0.0)", toId: "s\($0.1)") }

            items.append(
                ServerConstellationPayload(
                    id: "payload-\(name.replacingOccurrences(of: " ", with: "-").lowercased())",
                    name: name,
                    visualStyle: .skyBlue,
                    representativePoint: ServerPoint(x: representative.x, y: representative.y),
                    stars: stars,
                    edges: edges
                )
            )
        }

        return items
    }

    private static func bigDipperPayload() -> ServerConstellationPayload {
        let points: [CGPoint] = [
            // Dubhe, Merak, Phecda, Megrez, Alioth, Mizar, Alkaid
            CGPoint(x: -0.19, y: 0.11),
            CGPoint(x: -0.19, y: -0.02),
            CGPoint(x: -0.06, y: -0.06),
            CGPoint(x: 0.02, y: 0.05),
            CGPoint(x: 0.15, y: 0.10),
            CGPoint(x: 0.25, y: 0.12),
            CGPoint(x: 0.35, y: 0.09)
        ]
        let representative = representativePoint(from: points)
        let stars = points.enumerated().map { index, p in
            ServerRelativeStar(
                id: "s\(index)",
                dx: p.x - representative.x,
                dy: p.y - representative.y
            )
        }
        let edges: [ServerEdge] = [
            ServerEdge(fromId: "s0", toId: "s1"),
            ServerEdge(fromId: "s1", toId: "s2"),
            ServerEdge(fromId: "s2", toId: "s3"),
            ServerEdge(fromId: "s3", toId: "s0"),
            ServerEdge(fromId: "s3", toId: "s4"),
            ServerEdge(fromId: "s4", toId: "s5"),
            ServerEdge(fromId: "s5", toId: "s6")
        ]

        return ServerConstellationPayload(
            id: "payload-big-dipper",
            name: "Big Dipper",
            visualStyle: .debugRed,
            representativePoint: ServerPoint(x: representative.x, y: representative.y),
            stars: stars,
            edges: edges
        )
    }

    private static func makeTemplatePoints(starCount: Int, seed: UInt64) -> [CGPoint] {
        var state: UInt64 = (seed == 0 ? 0xA17C9E2B : seed)
        func next(_ state: inout UInt64) -> UInt64 {
            state = 6364136223846793005 &* state &+ 1442695040888963407
            return state
        }
        func nextCGFloat(_ state: inout UInt64, in range: ClosedRange<CGFloat>) -> CGFloat {
            let ratio = Double(next(&state) & 0xFFFF_FFFF) / Double(UInt32.max)
            return range.lowerBound + CGFloat(ratio) * (range.upperBound - range.lowerBound)
        }

        let rx = nextCGFloat(&state, in: 0.07...0.14)
        let ry = nextCGFloat(&state, in: 0.06...0.12)
        let phase = nextCGFloat(&state, in: 0...(2 * .pi))

        var points: [CGPoint] = []
        for index in 0..<starCount {
            let t = CGFloat(index) / CGFloat(max(1, starCount - 1))
            let angle = (t * 2 * .pi) + phase + nextCGFloat(&state, in: -0.18...0.18)
            let radial = 0.65 + 0.28 * sin(t * 3.6 * .pi + phase) + nextCGFloat(&state, in: -0.08...0.08)
            let x = cos(angle) * rx * radial
            let y = sin(angle) * ry * (0.78 + 0.22 * cos(t * 2.2 * .pi + phase))
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }

    private static func makeTemplateEdges(starCount: Int) -> [(Int, Int)] {
        var edges: [(Int, Int)] = []
        for i in 0..<(starCount - 1) {
            edges.append((i, i + 1))
        }
        if starCount >= 8 {
            let step = max(3, starCount / 6)
            var i = 0
            while i + step < starCount {
                edges.append((i, i + step))
                i += step
            }
        }
        return edges
    }

    private static func representativePoint(from points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let x = points.map(\.x).reduce(0, +) / CGFloat(points.count)
        let y = points.map(\.y).reduce(0, +) / CGFloat(points.count)
        return CGPoint(x: x, y: y)
    }
}
