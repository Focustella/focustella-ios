import Foundation

enum SessionStatus: String, Codable, Hashable {
    case running
    case paused
    case completed
    case canceled
}

struct FocusSession: Identifiable, Hashable {
    let id: UUID
    let serverSessionId: String?
    let serverConstellationId: Int?
    let startedAt: Date
    var endedAt: Date?
    let slotSeconds: Int
    let constellationId: UUID
    var discoveredStarCount: Int
    var status: SessionStatus
    var memo: SessionMemo?

    init(
        id: UUID = UUID(),
        serverSessionId: String? = nil,
        serverConstellationId: Int? = nil,
        startedAt: Date,
        endedAt: Date? = nil,
        slotSeconds: Int,
        constellationId: UUID,
        discoveredStarCount: Int = 0,
        status: SessionStatus,
        memo: SessionMemo? = nil
    ) {
        self.id = id
        self.serverSessionId = serverSessionId
        self.serverConstellationId = serverConstellationId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.slotSeconds = slotSeconds
        self.constellationId = constellationId
        self.discoveredStarCount = discoveredStarCount
        self.status = status
        self.memo = memo
    }
}

struct SessionMemo: Hashable {
    var topicTags: [String]
    var rating: Int
    var freeText: String?
}
