import SwiftUI
import os

@MainActor
final class MySkySessionDirector {
    private let logger = Logger(subsystem: "focustella-ios", category: "FocusSession")

    struct Context {
        let sessionStore: FocusSessionRuntimeStoring

        var skyState: Binding<MySkySceneState>
        var livePresentationState: Binding<FocusSessionPresentationState>
        var activeStarBirthEffect: Binding<StarBirthEffectState?>
        var spawnEffectToken: Binding<Int>
        var tutorialWarpTask: Binding<Task<Void, Never>?>
        var completionFlowTask: Binding<Task<Void, Never>?>
        var pendingMemoSessionId: Binding<UUID?>
        var selectedSession: Binding<FocusSession?>
        var completionConstellation: Binding<Constellation?>
        var completionEdgeOrder: Binding<[Int]>
        var showCompletionOverlay: Binding<Bool>
        var showCompletionRecordButton: Binding<Bool>
        var canvasSize: Binding<CGSize>

        let constellationById: (UUID) -> Constellation?
        let cameraForSky: (CGPoint, CGFloat, CGSize) -> MySkyCameraState
        let cameraForStar: (Star, CGFloat, CGSize) -> MySkyCameraState
        let logCameraTarget: (String, CGPoint, CGSize, MySkyCameraState) -> Void
        let animateCamera: (MySkyCameraState, TimeInterval, (@MainActor () -> Void)?) -> Void
        let triggerSpawnEffectIfNeeded: (Constellation, Int) -> TimeInterval
        let scheduleVisibleEdgeReveal: (UUID, Int, TimeInterval) -> Void
        let beginEdgeRevealAnimation: (Constellation, Int, TimeInterval) -> Void
        let focusOnConstellationOverview: (Constellation, CGSize) -> Void

        let tutorialSessionZoom: CGFloat
        let sessionAutoZoom: CGFloat
    }

    func beginLiveSession(
        constellation: Constellation,
        slotSeconds: Int,
        startedAt: Date,
        clock: FocusSessionClock,
        serverSessionId: String?,
        serverConstellationId: Int?,
        size: CGSize,
        context: Context
    ) {
        context.completionFlowTask.wrappedValue?.cancel()
        context.showCompletionOverlay.wrappedValue = false
        context.showCompletionRecordButton.wrappedValue = false
        context.pendingMemoSessionId.wrappedValue = nil
        context.activeStarBirthEffect.wrappedValue = nil

        context.skyState.wrappedValue.upsertConstellation(constellation)
        context.skyState.wrappedValue.setVisibleDiscoveredCount(0, for: constellation.id)
        context.skyState.wrappedValue.setEdgeRevealState(MySkyEdgeRevealState(), for: constellation.id)

        context.sessionStore.startSession(
            slotSeconds: slotSeconds,
            constellationId: constellation.id,
            serverSessionId: serverSessionId,
            serverConstellationId: serverConstellationId,
            now: startedAt
        )

        let liveSessionStartPayload: [String: Any] = [
            "event": "live-session-start",
            "constellationId": constellation.id.uuidString,
            "stars": constellation.starCount,
            "slotSeconds": slotSeconds,
            "representativePoint": LogJSONFormatter.point(constellation.representativePoint)
        ]
        logger.notice(
            "\(LogJSONFormatter.pretty(liveSessionStartPayload), privacy: .public)"
        )

        beginLivePresentation(
            for: constellation,
            clock: clock,
            size: size,
            context: context
        )
    }

    func beginLivePresentation(
        for constellation: Constellation,
        clock: FocusSessionClock,
        size: CGSize,
        context: Context
    ) {
        let bootstrap = MySkyFocusSessionPresentation(
            constellation: constellation,
            actualDiscoveredCount: 0,
            renderedDiscoveredCount: 0,
            edgeRevealState: MySkyEdgeRevealState(),
            activeBirthEffect: nil
        )

        context.livePresentationState.wrappedValue = FocusSessionPresentationState(
            constellationId: constellation.id,
            discoveryOrder: bootstrap.discoveryOrder,
            actualDiscoveredCount: 0,
            renderedDiscoveredCount: 0,
            currentTargetOrderIndex: nil,
            activeBirthStarId: nil,
            phase: .idle,
            clock: clock
        )

        if context.livePresentationState.wrappedValue.isTutorialClock {
            let targetCamera = context.cameraForSky(
                constellation.representativePoint,
                context.tutorialSessionZoom,
                size
            )

            context.logCameraTarget(
                "tutorial-fixed-representative constellation=\(constellation.id.uuidString)",
                constellation.representativePoint,
                size,
                targetCamera
            )

            context.animateCamera(targetCamera, 0.55) {
                guard context.livePresentationState.wrappedValue.constellationId == constellation.id else { return }
                self.updateLivePresentationState(context) { state in
                    state.currentTargetOrderIndex = 0
                    state.phase = .waitingToBirth(orderIndex: 0)
                }
                self.reconcileLivePresentation(constellation: constellation, size: size, context: context)
            }
            return
        }

        movePresentationCamera(toOrderIndex: 0, constellation: constellation, size: size, context: context)
    }

    func movePresentationCamera(
        toOrderIndex orderIndex: Int,
        constellation: Constellation,
        size: CGSize,
        context: Context
    ) {
        guard context.livePresentationState.wrappedValue.constellationId == constellation.id else { return }
        guard context.livePresentationState.wrappedValue.discoveryOrder.indices.contains(orderIndex) else { return }

        let starIndex = context.livePresentationState.wrappedValue.discoveryOrder[orderIndex]
        guard constellation.stars.indices.contains(starIndex) else { return }

        updateLivePresentationState(context) { state in
            state.currentTargetOrderIndex = orderIndex
            state.phase = .movingToTarget(orderIndex: orderIndex)
        }

        let targetStar = constellation.stars[starIndex]
        let targetCamera = context.cameraForStar(targetStar, context.sessionAutoZoom, size)

        context.logCameraTarget(
            "session-next-star constellation=\(constellation.id.uuidString)",
            CGPoint(x: targetStar.x, y: targetStar.y),
            size,
            targetCamera
        )

        context.animateCamera(targetCamera, 1.05) {
            guard context.livePresentationState.wrappedValue.constellationId == constellation.id else { return }
            guard case .movingToTarget(let currentOrder) = context.livePresentationState.wrappedValue.phase, currentOrder == orderIndex else { return }

            self.updateLivePresentationState(context) { state in
                state.phase = .waitingToBirth(orderIndex: orderIndex)
            }

            self.reconcileLivePresentation(constellation: constellation, size: size, context: context)
        }
    }

    func reconcileLivePresentation(
        constellation: Constellation,
        size: CGSize,
        context: Context
    ) {
        guard context.livePresentationState.wrappedValue.constellationId == constellation.id else { return }
        if context.livePresentationState.wrappedValue.canBeginBirth {
            beginBirthPresentation(constellation: constellation, size: size, context: context)
        }
    }

    func beginBirthPresentation(
        constellation: Constellation,
        size: CGSize,
        context: Context
    ) {
        guard context.livePresentationState.wrappedValue.constellationId == constellation.id else { return }
        guard let orderIndex = context.livePresentationState.wrappedValue.nextOrderIndexToRender else { return }

        let discoveredCount = orderIndex + 1
        let duration = context.triggerSpawnEffectIfNeeded(constellation, discoveredCount)

        context.scheduleVisibleEdgeReveal(constellation.id, discoveredCount, duration)
        context.beginEdgeRevealAnimation(constellation, discoveredCount, duration)

        let token = context.spawnEffectToken.wrappedValue
        updateLivePresentationState(context) { state in
            state.phase = .birthing(orderIndex: orderIndex, token: token)
            state.activeBirthStarId = context.activeStarBirthEffect.wrappedValue?.starId
        }

        Task { @MainActor in
            if duration > 0 {
                try? await Task.sleep(for: .seconds(duration))
            }

            guard context.livePresentationState.wrappedValue.constellationId == constellation.id else { return }
            guard case .birthing(let activeOrder, let activeToken) = context.livePresentationState.wrappedValue.phase,
                  activeOrder == orderIndex,
                  activeToken == token else { return }

            context.activeStarBirthEffect.wrappedValue = nil
            updateLivePresentationState(context) { state in
                state.renderedDiscoveredCount = discoveredCount
                state.activeBirthStarId = nil
            }

            if discoveredCount >= constellation.starCount {
                startCompletionWrapUp(constellation: constellation, size: size, context: context)
            } else if context.livePresentationState.wrappedValue.isTutorialClock {
                updateLivePresentationState(context) { state in
                    state.currentTargetOrderIndex = discoveredCount
                    state.phase = .waitingToBirth(orderIndex: discoveredCount)
                }
                reconcileLivePresentation(constellation: constellation, size: size, context: context)
            } else {
                movePresentationCamera(
                    toOrderIndex: discoveredCount,
                    constellation: constellation,
                    size: size,
                    context: context
                )
                reconcileLivePresentation(constellation: constellation, size: size, context: context)
            }
        }
    }

    func syncSession(now: Date, context: Context) {
        guard let session = context.sessionStore.currentSession,
              let constellation = context.constellationById(session.constellationId) else {
            return
        }

        let result = context.sessionStore.refreshCurrentSession(
            now: now,
            totalStars: constellation.starCount
        )

        let actualDiscoveredCount = result.completed?.discoveredStarCount
            ?? context.sessionStore.currentSession?.discoveredStarCount
            ?? session.discoveredStarCount

        if context.livePresentationState.wrappedValue.constellationId == constellation.id {
            updateLivePresentationState(context) { state in
                state.actualDiscoveredCount = actualDiscoveredCount
            }
        }

        let renderedCount: Int
        if context.livePresentationState.wrappedValue.constellationId == constellation.id {
            renderedCount = context.livePresentationState.wrappedValue.renderedDiscoveredCount
        } else {
            renderedCount = context.skyState.wrappedValue.visibleDiscoveredStarCounts[constellation.id] ?? 0
        }

        let tickPayload: [String: Any] = [
            "event": "session-tick",
            "constellationId": constellation.id.uuidString,
            "actualDiscoveredCount": actualDiscoveredCount,
            "renderedDiscoveredCount": renderedCount,
            "totalStars": constellation.starCount
        ]
        logger.debug("\(LogJSONFormatter.compact(tickPayload), privacy: .public)")

        if let completed = result.completed {
            handleSessionCompleted(completed, context: context)
        }

        reconcileLivePresentation(
            constellation: constellation,
            size: context.canvasSize.wrappedValue,
            context: context
        )
    }

    func handleSessionCompleted(_ completed: FocusSession, context: Context) {
        context.pendingMemoSessionId.wrappedValue = completed.id
        context.selectedSession.wrappedValue = nil
        context.tutorialWarpTask.wrappedValue?.cancel()
        context.completionConstellation.wrappedValue = nil
        context.completionEdgeOrder.wrappedValue = []
    }

    func startCompletionWrapUp(
        constellation: Constellation,
        size: CGSize,
        context: Context
    ) {
        context.completionFlowTask.wrappedValue?.cancel()
        updateLivePresentationState(context) { state in
            state.phase = .overviewing
        }
        context.completionFlowTask.wrappedValue = Task { @MainActor in
            context.focusOnConstellationOverview(constellation, size)
        }
    }

    func prepareFinalStarOnlyBirth(
        constellation: Constellation,
        size: CGSize,
        context: Context
    ) {
        guard context.livePresentationState.wrappedValue.constellationId == constellation.id else { return }
        guard constellation.starCount > 0 else { return }

        let finalOrderIndex = constellation.starCount - 1
        let settledDiscoveredCount = max(0, constellation.starCount - 1)

        context.completionFlowTask.wrappedValue?.cancel()
        context.activeStarBirthEffect.wrappedValue = nil

        updateLivePresentationState(context) { state in
            state.actualDiscoveredCount = constellation.starCount
            state.renderedDiscoveredCount = settledDiscoveredCount
            state.activeBirthStarId = nil
            state.currentTargetOrderIndex = finalOrderIndex
        }

        context.skyState.wrappedValue.setVisibleDiscoveredCount(settledDiscoveredCount, for: constellation.id)
        context.skyState.wrappedValue.setEdgeRevealState(
            MySkyEdgeRevealState(
                committedDiscoveredCount: settledDiscoveredCount,
                pendingDiscoveredCount: nil,
                progress: 0
            ),
            for: constellation.id
        )

        movePresentationCamera(
            toOrderIndex: finalOrderIndex,
            constellation: constellation,
            size: size,
            context: context
        )
    }

    private func updateLivePresentationState(
        _ context: Context,
        _ mutate: (inout FocusSessionPresentationState) -> Void
    ) {
        var state = context.livePresentationState.wrappedValue
        mutate(&state)
        context.livePresentationState.wrappedValue = state
    }
}
