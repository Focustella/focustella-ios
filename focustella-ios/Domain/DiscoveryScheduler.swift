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
        let normalized = clampedElapsed / TimeInterval(durationSeconds)
        return min(totalStars, Int(floor(normalized * TimeInterval(totalStars))))
    }

    func progressToNextStar(elapsedActive: TimeInterval, durationSeconds: Int, totalStars: Int) -> Double {
        guard totalStars > 0, durationSeconds > 0 else { return 1 }
        let intervalValue = interval(durationSeconds: durationSeconds, totalStars: totalStars)
        guard intervalValue > 0 else { return 1 }

        let clampedElapsed = min(max(elapsedActive, 0), TimeInterval(durationSeconds))
        let discovered = discoveredStarCount(
            elapsedActive: clampedElapsed,
            durationSeconds: durationSeconds,
            totalStars: totalStars
        )
        if discovered >= totalStars {
            return 1
        }

        let nextEventElapsed = TimeInterval(discovered + 1) * intervalValue
        let previousEventElapsed = TimeInterval(discovered) * intervalValue
        let segment = max(0.0001, nextEventElapsed - previousEventElapsed)
        return min(1, max(0, (clampedElapsed - previousEventElapsed) / segment))
    }

    func syncDiscoveredStarCount(
        now: Date,
        startedAt: Date,
        pausedAccumulated: TimeInterval,
        pausedAt: Date?,
        elapsedOffset: TimeInterval = 0,
        durationSeconds: Int,
        totalStars: Int
    ) -> Int {
        let effectiveNow = pausedAt ?? now
        let elapsed = effectiveNow.timeIntervalSince(startedAt) - pausedAccumulated + elapsedOffset
        return discoveredStarCount(elapsedActive: elapsed, durationSeconds: durationSeconds, totalStars: totalStars)
    }
}
