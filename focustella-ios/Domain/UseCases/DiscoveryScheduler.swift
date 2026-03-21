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
        elapsedOffset: TimeInterval, // 🔥 타임워프 파라미터 융합
        durationSeconds: Int,
        totalStars: Int
    ) -> Int {
        guard totalStars > 0 else { return 0 }
        
        let effectiveNow = pausedAt ?? now
        // 🔥 진짜 시간 + 타임워프로 당긴 시간(elapsedOffset) 합산
        let elapsed = max(0, effectiveNow.timeIntervalSince(startedAt) - pausedAccumulated + elapsedOffset)
        
        // HEAD에 있던 안전한 계산 함수를 재활용합니다.
        return discoveredStarCount(elapsedActive: elapsed, durationSeconds: durationSeconds, totalStars: totalStars)
    }
}
