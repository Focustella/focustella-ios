import CoreGraphics
import Foundation

enum SkyMapper {
    static func mapConstellation(_ dto: ConstellationDTO) -> Constellation {
        let id = deterministicUUID(input: "constellation|\(dto.id)")
        let stars = dto.stars.map {
            Star(
                id: deterministicUUID(input: "constellation|\(dto.id)|star|\($0.id)"),
                x: normalizedCoordinate($0.vectorX),
                y: normalizedCoordinate($0.vectorY)
            )
        }

        let starMap = Dictionary(uniqueKeysWithValues: zip(dto.stars.map(\.id), stars.map(\.id)))
        let edges = dto.edges.compactMap { edge -> Edge? in
            guard let from = starMap[edge.fromStarId], let to = starMap[edge.toStarId] else {
                return nil
            }
            return Edge(from: from, to: to)
        }

        return Constellation(
            id: id,
            serverId: dto.id,
            name: dto.name,
            visualStyle: .skyBlue,
            stars: stars,
            edges: edges
        )
    }

    static func mapFocusSession(_ dto: FocusSessionRecordDTO, constellationId: UUID? = nil) -> FocusSession? {
        guard let startedAt = parseDate(dto.startedAt), let endedAt = parseDate(dto.endedAt) else {
            return nil
        }

        let memo = SessionMemo(
            topicTags: dto.topicTags,
            rating: dto.rating,
            freeText: dto.freeText
        )

        return FocusSession(
            id: deterministicUUID(input: "focus-session|\(dto.sessionId)"),
            serverSessionId: dto.sessionId,
            serverConstellationId: dto.constellationId,
            startedAt: startedAt,
            endedAt: endedAt,
            slotSeconds: dto.slotSeconds,
            constellationId: constellationId ?? deterministicUUID(input: "constellation|\(dto.constellationId)"),
            discoveredStarCount: dto.discoveredStarCount,
            status: .completed,
            memo: memo
        )
    }

    static func mapDailyStars(seed: Int64, dailyStars: [SkyDailyStarDTO]) -> [CGPoint] {
        dailyStars.map { dailyStarPosition(seed: seed, sessionId: $0.sessionId) }
    }

    private static func normalizedCoordinate(_ value: Double) -> CGFloat {
        let clamped = max(-100.0, min(100.0, value))
        return CGFloat((clamped + 100.0) / 200.0)
    }

    private static func dailyStarPosition(seed: Int64, sessionId: String) -> CGPoint {
        var state = fnv1a64("\(seed)|\(sessionId)")

        func nextUnit() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let ratio = Double(state & 0xFFFF_FFFF) / Double(UInt32.max)
            return CGFloat(ratio)
        }

        let x = 0.15 + nextUnit() * 0.7
        let y = 0.1 + nextUnit() * 0.4
        return CGPoint(x: x, y: y)
    }

    private static func deterministicUUID(input: String) -> UUID {
        UUID(uuidString: deterministicUUIDString(input: input)) ?? UUID()
    }

    private static func deterministicUUIDString(input: String) -> String {
        let hash = fnv1a64(input)
        let hex = String(format: "%032llx", hash)
        return "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
    }

    private static func fnv1a64(_ input: String) -> UInt64 {
        let bytes = Array(input.utf8)
        var hash: UInt64 = 14695981039346656037
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return date
        }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return fallback.date(from: value)
    }
}
