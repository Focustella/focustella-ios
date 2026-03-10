import Foundation

struct ConstellationMatcher {
    func pick(durationSeconds: Int, from constellations: [Constellation]) -> Constellation? {
        guard !constellations.isEmpty else { return nil }

        let primaryRange = targetRange(for: durationSeconds)
        let exactCandidates = constellations.filter { primaryRange.contains($0.starCount) }
        if let picked = exactCandidates.randomElement() {
            return picked
        }

        let fallbackRange = nearestRange(to: primaryRange)
        let fallbackCandidates = constellations.filter { fallbackRange.contains($0.starCount) }
        if let picked = fallbackCandidates.randomElement() {
            return picked
        }

        return constellations.randomElement()
    }

    private func targetRange(for durationSeconds: Int) -> ClosedRange<Int> {
        switch durationSeconds {
        case ..<3600:
            return 5...7
        case 3600..<7200:
            return 8...10
        case 7200..<10800:
            return 11...20
        default:
            return 21...40
        }
    }

    private func nearestRange(to range: ClosedRange<Int>) -> ClosedRange<Int> {
        let ranges: [ClosedRange<Int>] = [5...7, 8...10, 11...20, 21...40]
        let center = Double(range.lowerBound + range.upperBound) / 2.0
        let candidates = ranges.filter { $0 != range }
        return candidates.min { a, b in
            let ca = Double(a.lowerBound + a.upperBound) / 2.0
            let cb = Double(b.lowerBound + b.upperBound) / 2.0
            return abs(ca - center) < abs(cb - center)
        } ?? (5...7)
    }
}
