import Foundation

struct MySkyFocusSessionPresentation {
    let constellation: Constellation
    let actualDiscoveredCount: Int
    let renderedDiscoveredCount: Int
    let edgeRevealState: MySkyEdgeRevealState
    let activeBirthEffect: StarBirthEffectState?
    let discoveryOrder: [Int]

    enum Phase: Equatable {
        case waitingForSchedule(orderIndex: Int)
        case birthing(orderIndex: Int)
        case completed
    }

    init(
        constellation: Constellation,
        actualDiscoveredCount: Int,
        renderedDiscoveredCount: Int,
        edgeRevealState: MySkyEdgeRevealState,
        activeBirthEffect: StarBirthEffectState?,
        discoveryOrder: [Int]? = nil
    ) {
        self.constellation = constellation
        self.actualDiscoveredCount = actualDiscoveredCount
        self.renderedDiscoveredCount = renderedDiscoveredCount
        self.edgeRevealState = edgeRevealState
        self.activeBirthEffect = activeBirthEffect
        self.discoveryOrder = discoveryOrder ?? MySkyConstellationRenderMetadata(constellation: constellation).discoveryOrder
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
