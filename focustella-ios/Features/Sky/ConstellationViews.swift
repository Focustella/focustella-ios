import SwiftUI

struct ConstellationView: View {
    let constellation: Constellation
    let size: CGSize
    let timeOverride: TimeInterval?

    var body: some View {
        ZStack {
            TimelineView(.animation) { context in
                ConstellationLinesView(
                    size: size,
                    edges: resolvedEdges(),
                    time: timeOverride ?? context.date.timeIntervalSinceReferenceDate
                )
            }
            .allowsHitTesting(false)

            ForEach(constellation.stars) { star in
                let position = CGPoint(x: star.position.x * size.width, y: star.position.y * size.height)
                Circle()
                    .fill(StarColor.paleBlue.primary)
                    .frame(width: 4, height: 4)
                    .position(position)
                TwinklingStar(
                    position: position,
                    size: 13,
                    phaseOffset: Double(star.position.x * 30 + star.position.y * 15),
                    color: .paleBlue,
                    timeOverride: timeOverride,
                    animatesColor: false
                )
                .shadow(color: StarColor.paleBlue.glow(opacity: 0.9), radius: 6)
                .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func resolvedEdges() -> [ResolvedEdge] {
        let starsByID = Dictionary(uniqueKeysWithValues: constellation.stars.map { ($0.id, $0) })
        let indexByID = Dictionary(uniqueKeysWithValues: constellation.stars.enumerated().map { ($0.element.id, $0.offset) })

        var unique = Set<EdgeKey>()
        for edge in constellation.edges {
            guard indexByID[edge.fromID] != nil, indexByID[edge.toID] != nil else { continue }
            let a = min(edge.fromID, edge.toID)
            let b = max(edge.fromID, edge.toID)
            unique.insert(EdgeKey(fromID: a, toID: b))
        }

        let sorted = unique.sorted { lhs, rhs in
            let la = indexByID[lhs.fromID] ?? 0
            let lb = indexByID[lhs.toID] ?? 0
            let ra = indexByID[rhs.fromID] ?? 0
            let rb = indexByID[rhs.toID] ?? 0
            if la != ra { return la < ra }
            return lb < rb
        }

        return sorted.compactMap { key in
            guard let from = starsByID[key.fromID], let to = starsByID[key.toID] else { return nil }
            let ia = indexByID[key.fromID] ?? 0
            let ib = indexByID[key.toID] ?? 0
            let phase = Double(ia * 31 + ib * 17)
            return ResolvedEdge(id: key, from: from, to: to, phase: phase)
        }
    }

    struct EdgeKey: Hashable, Comparable {
        let fromID: UUID
        let toID: UUID

        static func < (lhs: EdgeKey, rhs: EdgeKey) -> Bool {
            if lhs.fromID.uuidString != rhs.fromID.uuidString {
                return lhs.fromID.uuidString < rhs.fromID.uuidString
            }
            return lhs.toID.uuidString < rhs.toID.uuidString
        }
    }

    struct ResolvedEdge: Identifiable {
        let id: EdgeKey
        let from: StarObject
        let to: StarObject
        let phase: Double
    }
}

struct ConstellationLinesView: View {
    let size: CGSize
    let edges: [ConstellationView.ResolvedEdge]
    let time: TimeInterval

    var body: some View {
        Canvas { context, _ in
            for edge in edges {
                let a = CGPoint(x: edge.from.position.x * size.width, y: edge.from.position.y * size.height)
                let b = CGPoint(x: edge.to.position.x * size.width, y: edge.to.position.y * size.height)
                let phase = edge.phase
                let flicker = (sin(time * 0.9 + phase) + 1) / 2
                let opacity = 0.2 + 0.5 * flicker
                let glow = 2.0 + 4.0 * flicker

                var path = Path()
                path.move(to: a)
                path.addLine(to: b)

                context.addFilter(.shadow(color: Color(red: 0.75, green: 0.85, blue: 1.0, opacity: opacity), radius: glow, x: 0, y: 0))
                context.stroke(
                    path,
                    with: .color(Color(red: 0.75, green: 0.85, blue: 1.0, opacity: opacity)),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                )
                context.addFilter(.shadow(color: .clear, radius: 0, x: 0, y: 0))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}
