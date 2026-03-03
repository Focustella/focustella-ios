import Foundation
import CoreGraphics

struct SkySceneData {
    let stars: [StarObject]
    let constellations: [Constellation]
}

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xdeadbeef : seed
    }

    mutating func next() -> UInt64 {
        // LCG: Numerical Recipes
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

struct SkyGenerator {
    struct Config {
        var starCount: Int = 64
        var constellationCount: Int = 5
        var centerBiasSigma: CGFloat = 0.18
        var minStarDistance: CGFloat = 0.03
    }

    private let config: Config

    init(config: Config = Config()) {
        self.config = config
    }

    mutating func generate(seed: UInt64) -> SkySceneData {
        var rng = SeededRNG(seed: seed)
        let constellations = generateConstellations(rng: &rng)
        let stars = generateAmbientStars(rng: &rng)
        return SkySceneData(stars: stars, constellations: constellations)
    }

    private mutating func generateAmbientStars(rng: inout SeededRNG) -> [StarObject] {
        var stars: [StarObject] = []
        var attempts = 0
        while stars.count < config.starCount && attempts < config.starCount * 20 {
            attempts += 1
            let p = randomNearCenter(rng: &rng)
            if stars.allSatisfy({ distance($0.position, p) > config.minStarDistance }) {
                stars.append(StarObject(position: p, color: randomStarColor(rng: &rng)))
            }
        }
        return stars
    }

    private mutating func generateConstellations(rng: inout SeededRNG) -> [Constellation] {
        let templates = ConstellationTemplate.samples
        var result: [Constellation] = []
        var allSegments: [(CGPoint, CGPoint)] = []

        for index in 0..<config.constellationCount {
            var placed = false
            var attempts = 0
            while !placed && attempts < 60 {
                attempts += 1
                let template = templates[index % templates.count]
                let anchor = randomNearCenter(rng: &rng)
                let angle = CGFloat(rng.nextDouble() * 2 * Double.pi)
                let scale = CGFloat(0.08 + rng.nextDouble() * 0.06)

                let stars = template.points.map { pt in
                    let rotated = rotate(pt, angle: angle)
                    let shifted = CGPoint(x: anchor.x + rotated.x * scale, y: anchor.y + rotated.y * scale)
                    return StarObject(position: clamp01(shifted), color: randomStarColor(rng: &rng))
                }

                let edges = template.edges.map { ConstellationEdge(fromID: stars[$0.0].id, toID: stars[$0.1].id) }
                let constellation = Constellation(name: "Constellation-\(index + 1)", anchor: anchor, stars: stars, edges: edges)

                let segments = segmentsFor(constellation: constellation)
                if !intersectsExisting(segments: segments, with: allSegments) {
                    allSegments.append(contentsOf: segments)
                    result.append(constellation)
                    placed = true
                }
            }
        }

        return result
    }

    private func segmentsFor(constellation: Constellation) -> [(CGPoint, CGPoint)] {
        let starsByID = Dictionary(uniqueKeysWithValues: constellation.stars.map { ($0.id, $0) })
        return constellation.edges.compactMap { edge in
            guard let a = starsByID[edge.fromID], let b = starsByID[edge.toID] else { return nil }
            return (a.position, b.position)
        }
    }

    private func intersectsExisting(segments: [(CGPoint, CGPoint)], with others: [(CGPoint, CGPoint)]) -> Bool {
        for s in segments {
            for o in others {
                if segmentsIntersect(s.0, s.1, o.0, o.1) {
                    return true
                }
            }
        }
        return false
    }

    private func randomNearCenter(rng: inout SeededRNG) -> CGPoint {
        // Box-Muller
        let u1 = max(1e-6, rng.nextDouble())
        let u2 = rng.nextDouble()
        let z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * Double.pi * u2)
        let u3 = max(1e-6, rng.nextDouble())
        let u4 = rng.nextDouble()
        let z1 = sqrt(-2.0 * log(u3)) * sin(2.0 * Double.pi * u4)

        let x = CGFloat(0.5 + z0 * Double(config.centerBiasSigma))
        let y = CGFloat(0.5 + z1 * Double(config.centerBiasSigma))
        return clamp01(CGPoint(x: x, y: y))
    }

    private func rotate(_ p: CGPoint, angle: CGFloat) -> CGPoint {
        let c = cos(angle)
        let s = sin(angle)
        return CGPoint(x: p.x * c - p.y * s, y: p.x * s + p.y * c)
    }

    private func clamp01(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 0.05), 0.95), y: min(max(p.y, 0.05), 0.95))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    private func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint, _ q1: CGPoint, _ q2: CGPoint) -> Bool {
        let d1 = direction(q1, q2, p1)
        let d2 = direction(q1, q2, p2)
        let d3 = direction(p1, p2, q1)
        let d4 = direction(p1, p2, q2)
        if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) {
            return true
        }
        return false
    }

    private func direction(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }

    private func randomStarColor(rng: inout SeededRNG) -> StarColor {
        let palette: [StarColor] = [.warmYellow, .paleBlue, .nebulaPurple, .emberRed, .aquaCyan]
        let index = Int(rng.next() % UInt64(palette.count))
        return palette[index]
    }
}

struct ConstellationTemplate {
    let points: [CGPoint]
    let edges: [(Int, Int)]

    static let samples: [ConstellationTemplate] = [
        ConstellationTemplate(
            points: [
                CGPoint(x: -0.8, y: -0.1),
                CGPoint(x: -0.3, y: -0.3),
                CGPoint(x: 0.2, y: 0.1),
                CGPoint(x: 0.6, y: -0.2),
                CGPoint(x: 0.9, y: 0.2),
                CGPoint(x: 0.3, y: 0.6)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5)]
        ),
        ConstellationTemplate(
            points: [
                CGPoint(x: -0.6, y: -0.2),
                CGPoint(x: -0.2, y: -0.4),
                CGPoint(x: 0.2, y: -0.1),
                CGPoint(x: 0.6, y: -0.3),
                CGPoint(x: 0.8, y: 0.2)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4)]
        ),
        ConstellationTemplate(
            points: [
                CGPoint(x: -0.3, y: -0.3),
                CGPoint(x: 0.3, y: -0.3),
                CGPoint(x: 0.4, y: 0.3),
                CGPoint(x: -0.2, y: 0.4)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 0)]
        )
    ]
}
