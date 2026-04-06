import CoreGraphics

struct MySkyRewardPlanner {
    let constellations: [Constellation]
    let dailyStars: [DailyStarItem]

    func makeRewardPoint(xRange: ClosedRange<CGFloat>, yRange: ClosedRange<CGFloat>) -> CGPoint {
        let constellationPoints = constellations.flatMap { ConstellationGeometry(constellation: $0).normalizedPoints }
        let representativePoints = constellations.map(\.representativePoint)
        let existingRewardPoints = dailyStars.map(\.position)

        var bestCandidate = CGPoint(x: 0.5, y: (yRange.lowerBound + yRange.upperBound) * 0.5)
        var bestScore: CGFloat = -.greatestFiniteMagnitude

        for _ in 0..<160 {
            let candidate = CGPoint(
                x: CGFloat.random(in: xRange),
                y: CGFloat.random(in: yRange)
            )

            let nearestReward = existingRewardPoints.map { hypot($0.x - candidate.x, $0.y - candidate.y) }.min() ?? 1
            let nearestStar = constellationPoints.map { hypot($0.x - candidate.x, $0.y - candidate.y) }.min() ?? 1
            let nearestRepresentative = representativePoints.map { hypot($0.x - candidate.x, $0.y - candidate.y) }.min() ?? 1
            let edgeDistance = min(
                candidate.x - xRange.lowerBound,
                xRange.upperBound - candidate.x,
                candidate.y - yRange.lowerBound,
                yRange.upperBound - candidate.y
            )

            if nearestReward >= 0.12, nearestStar >= 0.09, nearestRepresentative >= 0.14 {
                return candidate
            }

            let score = nearestReward * 1.4 + nearestStar * 1.2 + nearestRepresentative + edgeDistance * 0.35
            if score > bestScore {
                bestScore = score
                bestCandidate = candidate
            }
        }

        return bestCandidate
    }
}
