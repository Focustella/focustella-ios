import CoreGraphics
import Foundation

struct MySkyConstellationRenderMetadata: Identifiable {
    let constellation: Constellation
    let starSkyPoints: [CGPoint]
    let edgeIndexPairs: [(from: Int, to: Int)?]
    let discoveryOrder: [Int]
    let edgeIndicesByDiscoveredCount: [Set<Int>]
    let paletteSeed: Int

    private let starIndexById: [UUID: Int]

    var id: UUID { constellation.id }

    init(constellation: Constellation) {
        self.constellation = constellation
        self.starSkyPoints = constellation.stars.map { CGPoint(x: $0.x, y: $0.y) }

        let starIndexById = Dictionary(
            uniqueKeysWithValues: constellation.stars.enumerated().map { ($0.element.id, $0.offset) }
        )
        self.starIndexById = starIndexById
        self.edgeIndexPairs = constellation.edges.map { edge in
            guard let from = starIndexById[edge.from], let to = starIndexById[edge.to] else { return nil }
            return (from, to)
        }

        let discoveryOrder = Self.makeDiscoveryOrder(
            constellation: constellation,
            edgeIndexPairs: self.edgeIndexPairs
        )
        self.discoveryOrder = discoveryOrder
        self.edgeIndicesByDiscoveredCount = Self.makeEdgeIndicesByDiscoveredCount(
            discoveryOrder: discoveryOrder,
            edgeIndexPairs: self.edgeIndexPairs,
            starCount: constellation.stars.count
        )
        self.paletteSeed = constellation.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    }

    func starIndex(for id: UUID) -> Int? {
        starIndexById[id]
    }

    func star(forDiscoveredCount count: Int) -> Star? {
        let revealIndex = count - 1
        guard revealIndex >= 0, discoveryOrder.indices.contains(revealIndex) else { return nil }
        let starIndex = discoveryOrder[revealIndex]
        guard constellation.stars.indices.contains(starIndex) else { return nil }
        return constellation.stars[starIndex]
    }

    func discoveredStarIndices(forDiscoveredCount count: Int) -> Set<Int> {
        let safeCount = min(max(0, count), discoveryOrder.count)
        return Set(discoveryOrder.prefix(safeCount))
    }

    func stars(forDiscoveredCount count: Int) -> [Star] {
        discoveredStarIndices(forDiscoveredCount: count).sorted().compactMap {
            constellation.stars.indices.contains($0) ? constellation.stars[$0] : nil
        }
    }

    func visibleEdgeIndices(forDiscoveredCount count: Int) -> Set<Int> {
        let safeCount = min(max(0, count), edgeIndicesByDiscoveredCount.count - 1)
        return edgeIndicesByDiscoveredCount[safeCount]
    }

    private static func makeDiscoveryOrder(
        constellation: Constellation,
        edgeIndexPairs: [(from: Int, to: Int)?]
    ) -> [Int] {
        guard !constellation.stars.isEmpty else { return [] }

        let focus = ConstellationGeometry(constellation: constellation).visualFocusPoint
        let startIndex = constellation.stars.enumerated().min { lhs, rhs in
            let lhsDistance = hypot(lhs.element.x - focus.x, lhs.element.y - focus.y)
            let rhsDistance = hypot(rhs.element.x - focus.x, rhs.element.y - focus.y)
            if lhsDistance == rhsDistance { return lhs.offset < rhs.offset }
            return lhsDistance < rhsDistance
        }?.offset ?? 0

        var adjacency: [Int: Set<Int>] = [:]
        for pair in edgeIndexPairs.compactMap({ $0 }) {
            adjacency[pair.from, default: []].insert(pair.to)
            adjacency[pair.to, default: []].insert(pair.from)
        }

        func distanceToFocus(_ index: Int) -> CGFloat {
            hypot(constellation.stars[index].x - focus.x, constellation.stars[index].y - focus.y)
        }

        func starOrderPriority(_ lhs: Int, _ rhs: Int) -> Bool {
            let lhsDistance = distanceToFocus(lhs)
            let rhsDistance = distanceToFocus(rhs)
            if lhsDistance == rhsDistance { return lhs < rhs }
            return lhsDistance < rhsDistance
        }

        var visited: Set<Int> = []
        var order: [Int] = []

        func traverseDepthFirst(from root: Int) {
            var stack: [Int] = [root]
            while let current = stack.popLast() {
                guard !visited.contains(current) else { continue }
                visited.insert(current)
                order.append(current)

                let neighbors = adjacency[current, default: []]
                    .filter { !visited.contains($0) }
                    .sorted(by: starOrderPriority)

                for neighbor in neighbors.reversed() {
                    stack.append(neighbor)
                }
            }
        }

        traverseDepthFirst(from: startIndex)

        while visited.count < constellation.stars.count {
            guard let nextRoot = constellation.stars.indices
                .filter({ !visited.contains($0) })
                .min(by: starOrderPriority) else {
                break
            }
            traverseDepthFirst(from: nextRoot)
        }

        return order
    }

    private static func makeEdgeIndicesByDiscoveredCount(
        discoveryOrder: [Int],
        edgeIndexPairs: [(from: Int, to: Int)?],
        starCount: Int
    ) -> [Set<Int>] {
        var results = Array(repeating: Set<Int>(), count: starCount + 1)
        guard starCount > 0 else { return results }

        var discovered: Set<Int> = []
        for count in 1...starCount {
            if discoveryOrder.indices.contains(count - 1) {
                discovered.insert(discoveryOrder[count - 1])
            }

            var visible: Set<Int> = []
            for (index, pair) in edgeIndexPairs.enumerated()
            where pair.map({ discovered.contains($0.from) && discovered.contains($0.to) }) == true {
                visible.insert(index)
            }
            results[count] = visible
        }

        return results
    }
}
