import Foundation

@MainActor
protocol FocusSessionRuntimeStoring: AnyObject {
    var completedSessions: [FocusSession] { get }
    var currentSession: FocusSession? { get }

    func startSession(
        slotSeconds: Int,
        constellationId: UUID,
        serverSessionId: String?,
        serverConstellationId: Int?,
        now: Date
    )
    func replaceCompletedSessions(_ sessions: [FocusSession])
    func pause(now: Date)
    func resume(now: Date, remainingStars: Int)
    func cancel(now: Date)
    func refreshCurrentSession(
        now: Date,
        totalStars: Int
    ) -> (newlyDiscovered: Bool, completed: FocusSession?)
    func activeElapsed(now: Date) -> TimeInterval
    func remainingSeconds(now: Date) -> Int
    func pausedAccumulatedSeconds() -> TimeInterval
    func pausedAtDate() -> Date?
    func currentStatus() -> SessionStatus?
    func updateMemo(sessionId: UUID, memo: SessionMemo)
    func appendCompletedSession(_ session: FocusSession)
    func removeCompletedSessions(constellationIds: Set<UUID>)
    func latestSession(constellationId: UUID) -> FocusSession?
    func advanceToNextStar(
        totalStars: Int,
        now: Date,
        leadSeconds: TimeInterval
    ) -> (advanced: Bool, completed: FocusSession?)
    func advanceToFinalStar(
        totalStars: Int,
        now: Date,
        leadSeconds: TimeInterval
    ) -> Bool
    func fastForwardTutorial(by seconds: TimeInterval)
}
