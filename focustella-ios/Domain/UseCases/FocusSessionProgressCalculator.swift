import Foundation

struct FocusSessionProgressCalculator {
    private let scheduler: DiscoveryScheduler

    init(scheduler: DiscoveryScheduler = DiscoveryScheduler()) {
        self.scheduler = scheduler
    }

    func activeElapsed(
        startedAt: Date,
        now: Date,
        pausedAccumulated: TimeInterval,
        pausedAt: Date?,
        elapsedOffset: TimeInterval
    ) -> TimeInterval {
        let effectiveNow = pausedAt ?? now
        return max(0, effectiveNow.timeIntervalSince(startedAt) - pausedAccumulated + elapsedOffset)
    }

    func syncedDiscoveredStarCount(
        now: Date,
        startedAt: Date,
        pausedAccumulated: TimeInterval,
        pausedAt: Date?,
        elapsedOffset: TimeInterval,
        durationSeconds: Int,
        totalStars: Int
    ) -> Int {
        guard totalStars > 0 else { return 0 }

        let elapsed = activeElapsed(
            startedAt: startedAt,
            now: now,
            pausedAccumulated: pausedAccumulated,
            pausedAt: pausedAt,
            elapsedOffset: elapsedOffset
        )

        return scheduler.discoveredStarCount(
            elapsedActive: elapsed,
            durationSeconds: durationSeconds,
            totalStars: totalStars
        )
    }

    func shouldComplete(elapsedActive: TimeInterval, durationSeconds: Int) -> Bool {
        elapsedActive >= TimeInterval(durationSeconds)
    }

    func remainingSeconds(elapsedActive: TimeInterval, durationSeconds: Int) -> Int {
        let remaining = TimeInterval(durationSeconds) - elapsedActive
        return max(0, Int(remaining.rounded(.up)))
    }

    func nextStarAdvanceDelta(
        elapsedNow: TimeInterval,
        discoveredStarCount: Int,
        totalStars: Int,
        durationSeconds: Int,
        leadSeconds: TimeInterval
    ) -> TimeInterval {
        guard totalStars > 0 else { return 0 }
        let duration = TimeInterval(durationSeconds)
        let interval = duration / TimeInterval(totalStars)
        let nextEventElapsed = min(duration, TimeInterval(discoveredStarCount + 1) * interval)
        let targetElapsed = max(elapsedNow, nextEventElapsed - max(0, leadSeconds))
        return max(0, targetElapsed - elapsedNow)
    }

    func finalStarAdvanceDelta(
        elapsedNow: TimeInterval,
        durationSeconds: Int,
        leadSeconds: TimeInterval
    ) -> TimeInterval {
        let duration = TimeInterval(durationSeconds)
        let targetElapsed = max(elapsedNow, max(0, duration - max(0, leadSeconds)))
        return max(0, targetElapsed - elapsedNow)
    }
}
