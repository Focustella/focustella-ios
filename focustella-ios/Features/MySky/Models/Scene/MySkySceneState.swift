import Foundation

struct MySkySceneState {
    var remoteFocusLayoutItems: [FocusSkyLayoutItem] = []
    var visibleDiscoveredStarCounts: [UUID: Int] = [:]
    var edgeRevealStates: [UUID: MySkyEdgeRevealState] = [:]

    private var constellationsById: [UUID: Constellation] = [:]
    private var constellationOrder: [UUID] = []

    var constellations: [Constellation] {
        constellationOrder.compactMap { constellationsById[$0] }
    }

    func constellation(id: UUID) -> Constellation? {
        constellationsById[id]
    }

    func containsConstellation(id: UUID) -> Bool {
        constellationsById[id] != nil
    }

    mutating func replace(snapshot: MySkySnapshot) {
        remoteFocusLayoutItems = snapshot.remoteFocusLayoutItems
        replaceConstellations(snapshot.constellations)
        syncCompletedSessionRenderState(snapshot.completedSessions)
    }

    mutating func replaceMergedWorld(
        constellations: [Constellation],
        completedSessions: [FocusSession]
    ) {
        replaceConstellations(constellations)
        syncCompletedSessionRenderState(completedSessions)
    }

    mutating func replaceRemoteLayoutItems(_ items: [FocusSkyLayoutItem]) {
        remoteFocusLayoutItems = items
    }

    mutating func appendRemoteLayoutItem(_ item: FocusSkyLayoutItem) {
        remoteFocusLayoutItems.append(item)
    }

    mutating func removeRemoteLayoutItem(sessionId: String) {
        remoteFocusLayoutItems.removeAll { $0.sessionId == sessionId }
    }

    mutating func upsertConstellation(_ constellation: Constellation) {
        if constellationsById[constellation.id] == nil {
            constellationOrder.append(constellation.id)
        }
        constellationsById[constellation.id] = constellation
    }

    mutating func removeConstellations(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        constellationOrder.removeAll { ids.contains($0) }
        constellationsById = constellationsById.filter { !ids.contains($0.key) }
        visibleDiscoveredStarCounts = visibleDiscoveredStarCounts.filter { !ids.contains($0.key) }
        edgeRevealStates = edgeRevealStates.filter { !ids.contains($0.key) }
    }

    mutating func setVisibleDiscoveredCount(_ count: Int, for constellationId: UUID) {
        visibleDiscoveredStarCounts[constellationId] = count
    }

    mutating func setEdgeRevealState(_ state: MySkyEdgeRevealState, for constellationId: UUID) {
        edgeRevealStates[constellationId] = state
    }

    private mutating func replaceConstellations(_ constellations: [Constellation]) {
        constellationOrder = constellations.map(\.id)
        constellationsById = Dictionary(uniqueKeysWithValues: constellations.map { ($0.id, $0) })
    }

    private mutating func syncCompletedSessionRenderState(_ sessions: [FocusSession]) {
        visibleDiscoveredStarCounts = Dictionary(
            uniqueKeysWithValues: sessions.map { ($0.constellationId, $0.discoveredStarCount) }
        )
        edgeRevealStates = Dictionary(
            uniqueKeysWithValues: sessions.map {
                (
                    $0.constellationId,
                    MySkyEdgeRevealState(
                        committedDiscoveredCount: $0.discoveredStarCount,
                        pendingDiscoveredCount: nil,
                        progress: 0
                    )
                )
            }
        )
    }
}
