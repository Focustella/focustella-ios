import Foundation

struct DiscoveryScheduler {
    func interval(durationSeconds: Int, totalStars: Int) -> TimeInterval {
        guard durationSeconds > 0, totalStars > 0 else { return 0 }
        return TimeInterval(durationSeconds) / TimeInterval(totalStars)
    }

    func intervalAfterResume(remainingTime: TimeInterval, remainingStars: Int) -> TimeInterval {
        guard remainingTime > 0, remainingStars > 0 else { return 0 }
        return remainingTime / TimeInterval(remainingStars)
    }

    func discoveredStarCount(elapsedActive: TimeInterval, durationSeconds: Int, totalStars: Int) -> Int {
        guard totalStars > 0 else { return 0 }
        guard durationSeconds > 0 else { return totalStars }

        let clampedElapsed = min(max(elapsedActive, 0), TimeInterval(durationSeconds))
        if totalStars == 1 {
            return clampedElapsed > 0 ? 1 : 0
        }

        if clampedElapsed <= 0 {
            return 1
        }

        let normalized = clampedElapsed / TimeInterval(durationSeconds)
        let discoveredBeyondFirst = Int(floor(normalized * TimeInterval(totalStars - 1)))
        return min(totalStars, 1 + discoveredBeyondFirst)
    }

    func syncDiscoveredStarCount(
        now: Date,
        startedAt: Date,
        pausedAccumulated: TimeInterval,
        pausedAt: Date?,
        durationSeconds: Int,
        totalStars: Int
    ) -> Int {
        let effectiveNow = pausedAt ?? now
        let elapsed = effectiveNow.timeIntervalSince(startedAt) - pausedAccumulated
        return discoveredStarCount(elapsedActive: elapsed, durationSeconds: durationSeconds, totalStars: totalStars)
    }
}
