import CoreGraphics
import Foundation

struct MySkyRenderModel {
    func focusSessionPresentation(
        for constellation: Constellation,
        livePresentationState: FocusSessionPresentationState,
        currentSession: FocusSession?,
        latestSession: FocusSession?,
        visibleDiscoveredStarCounts: [UUID: Int],
        edgeRevealStates: [UUID: MySkyEdgeRevealState],
        activeStarBirthEffect: StarBirthEffectState?,
        renderMetadata: MySkyConstellationRenderMetadata?
    ) -> MySkyFocusSessionPresentation {
        let actualDiscoveredCount: Int
        let renderedDiscoveredCount: Int

        if livePresentationState.constellationId == constellation.id {
            actualDiscoveredCount = livePresentationState.actualDiscoveredCount
            renderedDiscoveredCount = livePresentationState.renderedDiscoveredCount
        } else if currentSession?.constellationId == constellation.id {
            actualDiscoveredCount = currentSession?.discoveredStarCount ?? 0
            renderedDiscoveredCount = visibleDiscoveredStarCounts[constellation.id] ?? 0
        } else {
            actualDiscoveredCount = max(
                visibleDiscoveredStarCounts[constellation.id] ?? 0,
                latestSession?.discoveredStarCount ?? 0
            )
            renderedDiscoveredCount = visibleDiscoveredStarCounts[constellation.id] ?? 0
        }

        return MySkyFocusSessionPresentation(
            constellation: constellation,
            actualDiscoveredCount: actualDiscoveredCount,
            renderedDiscoveredCount: renderedDiscoveredCount,
            edgeRevealState: edgeRevealStates[constellation.id] ?? MySkyEdgeRevealState(),
            activeBirthEffect: activeStarBirthEffect?.constellationId == constellation.id ? activeStarBirthEffect : nil,
            discoveryOrder: renderMetadata?.discoveryOrder
        )
    }

    func runningEdgeIndices(
        constellation: Constellation,
        discoveredCount: Int,
        renderMetadata: MySkyConstellationRenderMetadata?
    ) -> Set<Int> {
        guard discoveredCount > 0 else { return [] }
        if let renderMetadata {
            return renderMetadata.visibleEdgeIndices(forDiscoveredCount: discoveredCount)
        }

        let presentation = MySkyFocusSessionPresentation(
            constellation: constellation,
            actualDiscoveredCount: discoveredCount,
            renderedDiscoveredCount: discoveredCount,
            edgeRevealState: MySkyEdgeRevealState(),
            activeBirthEffect: nil
        )
        let discoveredIds = Set(presentation.stars(forDiscoveredCount: discoveredCount).map { $0.id })
        var indices: Set<Int> = []
        for (index, edge) in constellation.edges.enumerated() {
            if discoveredIds.contains(edge.from), discoveredIds.contains(edge.to) {
                indices.insert(index)
            }
        }
        return indices
    }

    func edgeRenderState(
        for constellation: Constellation,
        edgeRevealStates: [UUID: MySkyEdgeRevealState],
        renderMetadata: MySkyConstellationRenderMetadata?
    ) -> (visibleIndices: Set<Int>, visibilityOverrides: [Int: CGFloat]) {
        let state = edgeRevealStates[constellation.id] ?? MySkyEdgeRevealState()
        let committedIndices = runningEdgeIndices(
            constellation: constellation,
            discoveredCount: state.committedDiscoveredCount,
            renderMetadata: renderMetadata
        )
        guard let pendingCount = state.pendingDiscoveredCount else {
            return (committedIndices, [:])
        }

        let pendingIndices = runningEdgeIndices(
            constellation: constellation,
            discoveredCount: pendingCount,
            renderMetadata: renderMetadata
        )
        .subtracting(committedIndices)

        var visibilityOverrides = Dictionary(uniqueKeysWithValues: committedIndices.map { ($0, CGFloat(1)) })
        for index in pendingIndices {
            visibilityOverrides[index] = state.progress
        }
        return (committedIndices.union(pendingIndices), visibilityOverrides)
    }

    func settledItems(
        completedSessions: [FocusSession],
        skyState: MySkySceneState,
        completionConstellationId: UUID?,
        liveConstellationId: UUID?
    ) -> [SettledConstellationsCanvas.Item] {
        completedSessions.compactMap { session in
            guard completionConstellationId != session.constellationId,
                  liveConstellationId != session.constellationId,
                  let metadata = skyState.renderMetadata(id: session.constellationId) else {
                return nil
            }

            let constellation = metadata.constellation
            let visibleCount = skyState.visibleDiscoveredStarCounts[session.constellationId] ?? constellation.starCount
            let edgeState = edgeRenderState(
                for: constellation,
                edgeRevealStates: skyState.edgeRevealStates,
                renderMetadata: metadata
            )

            return SettledConstellationsCanvas.Item(
                metadata: metadata,
                discoveredStarCount: visibleCount,
                visibleEdgeIndices: edgeState.visibleIndices,
                edgeVisibilityOverrides: edgeState.visibilityOverrides
            )
        }
    }
}
