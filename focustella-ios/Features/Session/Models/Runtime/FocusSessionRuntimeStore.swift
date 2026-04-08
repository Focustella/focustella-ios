import Foundation
import Combine

@MainActor
final class FocusSessionRuntimeStore: ObservableObject, FocusSessionRuntimeStoring {
    @Published private(set) var completedSessions: [FocusSession] = []
    @Published private(set) var currentSession: FocusSession?

    private struct RuntimeState {
        var pausedAccumulated: TimeInterval
        var pausedAt: Date?
        var elapsedOffset: TimeInterval
    }

    private let progressCalculator = FocusSessionProgressCalculator()
    private var runtimeState: RuntimeState?

    func startSession(
        slotSeconds: Int,
        constellationId: UUID,
        serverSessionId: String? = nil,
        serverConstellationId: Int? = nil,
        now: Date = Date()
    ) {
        currentSession = FocusSession(
            startedAt: now,
            slotSeconds: slotSeconds,
            constellationId: constellationId,
            discoveredStarCount: 0,
            status: .running,
            memo: nil
        )

        if let currentSession {
            self.currentSession = FocusSession(
                id: currentSession.id,
                serverSessionId: serverSessionId,
                serverConstellationId: serverConstellationId,
                startedAt: currentSession.startedAt,
                endedAt: currentSession.endedAt,
                slotSeconds: currentSession.slotSeconds,
                constellationId: currentSession.constellationId,
                discoveredStarCount: currentSession.discoveredStarCount,
                status: currentSession.status,
                memo: currentSession.memo
            )
        }

        runtimeState = RuntimeState(pausedAccumulated: 0, pausedAt: nil, elapsedOffset: 0)
    }

    func replaceCompletedSessions(_ sessions: [FocusSession]) {
        completedSessions = sessions.sorted { lhs, rhs in
            (lhs.endedAt ?? lhs.startedAt) > (rhs.endedAt ?? rhs.startedAt)
        }
    }

    func pause(now: Date = Date()) {
        guard var session = currentSession, session.status == .running else { return }
        session.status = .paused
        currentSession = session
        runtimeState?.pausedAt = now
    }

    func resume(now: Date = Date(), remainingStars: Int) {
        guard var session = currentSession, session.status == .paused else { return }
        if let pausedAt = runtimeState?.pausedAt {
            runtimeState?.pausedAccumulated += now.timeIntervalSince(pausedAt)
            runtimeState?.pausedAt = nil
        }
        _ = remainingStars
        session.status = .running
        currentSession = session
    }

    func cancel(now: Date = Date()) {
        guard var session = currentSession else { return }
        session.status = .canceled
        session.endedAt = now
        currentSession = nil
        runtimeState = nil
    }

    func refreshCurrentSession(now: Date, totalStars: Int) -> (newlyDiscovered: Bool, completed: FocusSession?) {
        guard var session = currentSession else { return (false, nil) }
        guard let runtimeState else { return (false, nil) }

        let previousCount = session.discoveredStarCount

        let syncedCount = progressCalculator.syncedDiscoveredStarCount(
            now: now,
            startedAt: session.startedAt,
            pausedAccumulated: runtimeState.pausedAccumulated,
            pausedAt: runtimeState.pausedAt,
            elapsedOffset: runtimeState.elapsedOffset,
            durationSeconds: session.slotSeconds,
            totalStars: totalStars
        )

        session.discoveredStarCount = min(max(syncedCount, session.discoveredStarCount), totalStars)

        let elapsed = activeElapsed(now: now)
        if progressCalculator.shouldComplete(elapsedActive: elapsed, durationSeconds: session.slotSeconds) {
            session.discoveredStarCount = totalStars
            session.status = .completed
            session.endedAt = now
            currentSession = nil
            self.runtimeState = nil
            completedSessions.insert(session, at: 0)
            return (session.discoveredStarCount > previousCount, session)
        }

        currentSession = session
        return (session.discoveredStarCount > previousCount, nil)
    }

    func activeElapsed(now: Date = Date()) -> TimeInterval {
        guard let session = currentSession, let runtimeState else { return 0 }
        return progressCalculator.activeElapsed(
            startedAt: session.startedAt,
            now: now,
            pausedAccumulated: runtimeState.pausedAccumulated,
            pausedAt: runtimeState.pausedAt,
            elapsedOffset: runtimeState.elapsedOffset
        )
    }

    func remainingSeconds(now: Date = Date()) -> Int {
        guard let session = currentSession else { return 0 }
        return progressCalculator.remainingSeconds(
            elapsedActive: activeElapsed(now: now),
            durationSeconds: session.slotSeconds
        )
    }

    func pausedAccumulatedSeconds() -> TimeInterval {
        runtimeState?.pausedAccumulated ?? 0
    }

    func pausedAtDate() -> Date? {
        runtimeState?.pausedAt
    }

    func currentStatus() -> SessionStatus? {
        currentSession?.status
    }

    func updateMemo(sessionId: UUID, memo: SessionMemo) {
        guard let index = completedSessions.firstIndex(where: { $0.id == sessionId }) else { return }
        completedSessions[index].memo = memo
    }

    func appendCompletedSession(_ session: FocusSession) {
        completedSessions.removeAll { $0.id == session.id || $0.constellationId == session.constellationId }
        completedSessions.insert(session, at: 0)
    }

    func removeCompletedSessions(constellationIds: Set<UUID>) {
        guard !constellationIds.isEmpty else { return }
        completedSessions.removeAll { constellationIds.contains($0.constellationId) }
    }

    func latestSession(constellationId: UUID) -> FocusSession? {
        completedSessions.first { $0.constellationId == constellationId }
    }

    @discardableResult
    func advanceToNextStar(
        totalStars: Int,
        now: Date = Date(),
        leadSeconds: TimeInterval = 2
    ) -> (advanced: Bool, completed: FocusSession?) {
        guard totalStars > 0, let session = currentSession else { return (false, nil) }
        guard session.status == .running || session.status == .paused else { return (false, nil) }
        guard session.discoveredStarCount < totalStars else { return (false, nil) }
        guard var runtimeState else { return (false, nil) }

        let elapsedNow = activeElapsed(now: now)
        let delta = progressCalculator.nextStarAdvanceDelta(
            elapsedNow: elapsedNow,
            discoveredStarCount: session.discoveredStarCount,
            totalStars: totalStars,
            durationSeconds: session.slotSeconds,
            leadSeconds: leadSeconds
        )

        guard delta > 0 else { return (false, nil) }
        runtimeState.elapsedOffset += delta
        self.runtimeState = runtimeState

        currentSession = session
        return (true, nil)
    }

    @discardableResult
    func advanceToFinalStar(
        totalStars: Int,
        now: Date = Date(),
        leadSeconds: TimeInterval = 2
    ) -> Bool {
        guard totalStars > 0, let session = currentSession else { return false }
        guard session.status == .running || session.status == .paused else { return false }
        guard session.discoveredStarCount < totalStars else { return false }
        guard var runtimeState else { return false }

        let elapsedNow = activeElapsed(now: now)
        let delta = progressCalculator.finalStarAdvanceDelta(
            elapsedNow: elapsedNow,
            durationSeconds: session.slotSeconds,
            leadSeconds: leadSeconds
        )

        guard delta > 0 else { return false }
        runtimeState.elapsedOffset += delta
        self.runtimeState = runtimeState
        currentSession = session
        return true
    }

    func fastForwardTutorial(by seconds: TimeInterval) {
        guard var state = runtimeState, currentSession?.status == .running else { return }
        state.elapsedOffset += seconds
        runtimeState = state
        objectWillChange.send()
    }
}
