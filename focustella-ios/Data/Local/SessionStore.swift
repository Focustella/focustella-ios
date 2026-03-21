import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var completedSessions: [FocusSession] = []
    @Published private(set) var currentSession: FocusSession?

    // 1. 🔥 날아갔던 elapsedOffset 복구
    private struct RuntimeState {
        var pausedAccumulated: TimeInterval
        var pausedAt: Date?
        var elapsedOffset: TimeInterval
    }

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
            discoveredStarCount: 0, // 🔥 1에서 0으로 수정 (시작할 때 별은 0개부터)
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
        // 🔥 초기화에 elapsedOffset 추가
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

    func refreshCurrentSession(now: Date, totalStars: Int, scheduler: DiscoveryScheduler) -> (newlyDiscovered: Bool, completed: FocusSession?) {
        guard var session = currentSession else { return (false, nil) }
        guard let runtimeState else { return (false, nil) }

        let previousCount = session.discoveredStarCount
        
        let syncedCount = scheduler.syncDiscoveredStarCount(
            now: now,
            startedAt: session.startedAt,
            pausedAccumulated: runtimeState.pausedAccumulated,
            pausedAt: runtimeState.pausedAt,
            elapsedOffset: runtimeState.elapsedOffset, // 🔥 날아갔던 파라미터 복구
            durationSeconds: session.slotSeconds,
            totalStars: totalStars
        )

        session.discoveredStarCount = min(max(syncedCount, session.discoveredStarCount), totalStars)

        let elapsed = activeElapsed(now: now)
        if elapsed >= TimeInterval(session.slotSeconds) {
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

    // 2. 🔥 activeElapsed에 elapsedOffset 더하는 로직 복구
    func activeElapsed(now: Date = Date()) -> TimeInterval {
        guard let session = currentSession, let runtimeState else { return 0 }
        let effectiveNow = runtimeState.pausedAt ?? now
        return max(0, effectiveNow.timeIntervalSince(session.startedAt) - runtimeState.pausedAccumulated + runtimeState.elapsedOffset)
    }

    func remainingSeconds(now: Date = Date()) -> Int {
        guard let session = currentSession else { return 0 }
        let remaining = TimeInterval(session.slotSeconds) - activeElapsed(now: now)
        return max(0, Int(remaining.rounded(.up)))
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

    func latestSession(constellationId: UUID) -> FocusSession? {
        completedSessions.first { $0.constellationId == constellationId }
    }

    // 3. 🔥 advanceToNextStar 옛날 방식(숫자만 +1)에서 시간 타임워프 방식으로 복구
    @discardableResult
    func advanceToNextStar(
        totalStars: Int,
        now: Date = Date(),
        leadSeconds: TimeInterval = 5
    ) -> (advanced: Bool, completed: FocusSession?) {
        guard totalStars > 0, let session = currentSession else { return (false, nil) }
        guard session.status == .running || session.status == .paused else { return (false, nil) }
        guard session.discoveredStarCount < totalStars else { return (false, nil) }
        guard var runtimeState else { return (false, nil) }

        let elapsedNow = activeElapsed(now: now)
        let duration = TimeInterval(session.slotSeconds)
        let interval = duration / TimeInterval(totalStars)
        let nextEventElapsed = min(duration, TimeInterval(session.discoveredStarCount + 1) * interval)
        let targetElapsed = max(elapsedNow, nextEventElapsed - max(0, leadSeconds))
        let delta = max(0, targetElapsed - elapsedNow)

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
        let duration = TimeInterval(session.slotSeconds)
        let targetElapsed = max(elapsedNow, max(0, duration - max(0, leadSeconds)))
        let delta = max(0, targetElapsed - elapsedNow)

        guard delta > 0 else { return false }
        runtimeState.elapsedOffset += delta
        self.runtimeState = runtimeState
        currentSession = session
        return true
    }
    
    // MARK: - 튜토리얼용 타임워프 함수 (그대로 유지)
    func fastForwardTutorial(by seconds: TimeInterval) {
        guard var state = runtimeState, currentSession?.status == .running else { return }
        state.elapsedOffset += seconds
        self.runtimeState = state
        self.objectWillChange.send() // UI 즉각 갱신
    }
}
