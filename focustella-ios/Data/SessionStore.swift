import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var completedSessions: [FocusSession] = []
    @Published private(set) var currentSession: FocusSession?

    private struct RuntimeState {
        var pausedAccumulated: TimeInterval
        var pausedAt: Date?
    }

    private var runtimeState: RuntimeState?

    func startSession(slotSeconds: Int, constellationId: UUID, now: Date = Date()) {
        currentSession = FocusSession(
            startedAt: now,
            slotSeconds: slotSeconds,
            constellationId: constellationId,
            discoveredStarCount: 1,
            status: .running
        )
        runtimeState = RuntimeState(pausedAccumulated: 0, pausedAt: nil)
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

    func activeElapsed(now: Date = Date()) -> TimeInterval {
        guard let session = currentSession, let runtimeState else { return 0 }
        let effectiveNow = runtimeState.pausedAt ?? now
        return max(0, effectiveNow.timeIntervalSince(session.startedAt) - runtimeState.pausedAccumulated)
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

    func updateMemo(sessionId: UUID, memo: SessionMemo) {
        guard let index = completedSessions.firstIndex(where: { $0.id == sessionId }) else { return }
        completedSessions[index].memo = memo
    }

    func latestSession(constellationId: UUID) -> FocusSession? {
        completedSessions.first { $0.constellationId == constellationId }
    }

    @discardableResult
    func advanceToNextStar(totalStars: Int, now: Date = Date()) -> (advanced: Bool, completed: FocusSession?) {
        guard totalStars > 0, var session = currentSession else { return (false, nil) }
        guard session.status == .running || session.status == .paused else { return (false, nil) }
        guard session.discoveredStarCount < totalStars else { return (false, nil) }

        session.discoveredStarCount += 1
        if session.discoveredStarCount >= totalStars {
            session.discoveredStarCount = totalStars
            session.status = .completed
            session.endedAt = now
            currentSession = nil
            runtimeState = nil
            completedSessions.insert(session, at: 0)
            return (true, session)
        }

        currentSession = session
        return (true, nil)
    }
}
