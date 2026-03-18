import Foundation

struct DiscoveryScheduler {
    func syncDiscoveredStarCount(
        now: Date,
        startedAt: Date,
        pausedAccumulated: TimeInterval,
        pausedAt: Date?,
        elapsedOffset: TimeInterval, // 🔥 에러의 원인! 날아갔던 파라미터 복구 완료
        durationSeconds: Int,
        totalStars: Int
    ) -> Int {
        guard totalStars > 0 else { return 0 }
        
        let effectiveNow = pausedAt ?? now
        // 🔥 진짜 시간 + 타임워프로 당긴 시간(elapsedOffset)을 합쳐서 계산합니다.
        let elapsed = max(0, effectiveNow.timeIntervalSince(startedAt) - pausedAccumulated + elapsedOffset)
        
        if elapsed >= TimeInterval(durationSeconds) {
            return totalStars
        }
        
        let interval = TimeInterval(durationSeconds) / TimeInterval(totalStars)
        return Int(elapsed / interval)
    }

    func intervalAfterResume(remainingTime: TimeInterval, remainingStars: Int) -> TimeInterval {
        guard remainingStars > 0 else { return 0 }
        return remainingTime / TimeInterval(remainingStars)
    }
}
