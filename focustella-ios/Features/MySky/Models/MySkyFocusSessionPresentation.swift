import Foundation

struct MySkyFocusSessionPresentation {
    let constellation: Constellation
    let actualDiscoveredCount: Int
    let renderedDiscoveredCount: Int
    let edgeRevealState: MySkyEdgeRevealState
    let activeBirthEffect: StarBirthEffectState?

    enum Phase: Equatable {
        case waitingForSchedule(orderIndex: Int)
        case birthing(orderIndex: Int)
        case completed
    }

    var discoveryOrder: [Int] {
        guard !constellation.stars.isEmpty else { return [] }

        let focus = ConstellationGeometry(constellation: constellation).visualFocusPoint
        let idToIndex = Dictionary(uniqueKeysWithValues: constellation.stars.enumerated().map { ($0.element.id, $0.offset) })
        let startIndex = constellation.stars.enumerated().min { lhs, rhs in
            let lhsDistance = hypot(lhs.element.x - focus.x, lhs.element.y - focus.y)
            let rhsDistance = hypot(rhs.element.x - focus.x, rhs.element.y - focus.y)
            if lhsDistance == rhsDistance { return lhs.offset < rhs.offset }
            return lhsDistance < rhsDistance
        }?.offset ?? 0

        var adjacency: [Int: Set<Int>] = [:]
        for edge in constellation.edges {
            guard let fromIndex = idToIndex[edge.from], let toIndex = idToIndex[edge.to] else { continue }
            adjacency[fromIndex, default: []].insert(toIndex)
            adjacency[toIndex, default: []].insert(fromIndex)
        }

        func distanceToFocus(_ index: Int) -> CGFloat {
            hypot(constellation.stars[index].x - focus.x, constellation.stars[index].y - focus.y)
        }

        var queue: [Int] = [startIndex]
        var visited: Set<Int> = [startIndex]
        var order: [Int] = []

        while !queue.isEmpty {
            let current = queue.removeFirst()
            order.append(current)

            let neighbors = adjacency[current, default: []].sorted { lhs, rhs in
                let lhsDistance = distanceToFocus(lhs)
                let rhsDistance = distanceToFocus(rhs)
                if lhsDistance == rhsDistance { return lhs < rhs }
                return lhsDistance < rhsDistance
            }

            for neighbor in neighbors where !visited.contains(neighbor) {
                visited.insert(neighbor)
                queue.append(neighbor)
            }
        }

        let remaining = constellation.stars.indices.filter { !visited.contains($0) }.sorted { lhs, rhs in
            let lhsDistance = distanceToFocus(lhs)
            let rhsDistance = distanceToFocus(rhs)
            if lhsDistance == rhsDistance { return lhs < rhs }
            return lhsDistance < rhsDistance
        }
        order.append(contentsOf: remaining)
        return order
    }

    var discoveredStarIndices: Set<Int> {
        discoveredStarIndices(forDiscoveredCount: renderedDiscoveredCount)
    }

    var discoveredStars: [Star] {
        stars(forDiscoveredCount: renderedDiscoveredCount)
    }

    var committedDiscoveredCount: Int {
        min(max(0, renderedDiscoveredCount), discoveryOrder.count)
    }

    var queuedDiscoveredCount: Int {
        min(max(committedDiscoveredCount, actualDiscoveredCount), discoveryOrder.count)
    }

    var nextPendingOrderIndex: Int? {
        guard committedDiscoveredCount < queuedDiscoveredCount else { return nil }
        return committedDiscoveredCount
    }

    var targetOrderIndex: Int? {
        if let nextPendingOrderIndex {
            return nextPendingOrderIndex
        }
        guard committedDiscoveredCount < discoveryOrder.count else { return nil }
        return committedDiscoveredCount
    }

    var nextTargetStarIndex: Int? {
        guard let targetOrderIndex, discoveryOrder.indices.contains(targetOrderIndex) else { return nil }
        return discoveryOrder[targetOrderIndex]
    }

    var nextTargetStar: Star? {
        guard let nextTargetStarIndex, constellation.stars.indices.contains(nextTargetStarIndex) else { return nil }
        return constellation.stars[nextTargetStarIndex]
    }

    var phase: Phase {
        if let activeBirthEffect,
           let orderIndex = discoveryOrder.firstIndex(where: { constellation.stars[safe: $0]?.id == activeBirthEffect.starId }) {
            return .birthing(orderIndex: orderIndex)
        }
        if let nextPendingOrderIndex {
            return .waitingForSchedule(orderIndex: nextPendingOrderIndex)
        }
        return .completed
    }

    var hasPresentationInFlight: Bool {
        activeBirthEffect?.constellationId == constellation.id || edgeRevealState.pendingDiscoveredCount != nil
    }

    var previewStarIndices: Set<Int> {
        []
    }

    func birthStar(for discoveredCount: Int) -> Star? {
        let revealIndex = discoveredCount - 1
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
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
