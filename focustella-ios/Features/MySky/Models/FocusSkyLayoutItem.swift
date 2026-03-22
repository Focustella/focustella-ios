import Foundation

struct FocusSkyLayoutItem {
    let sessionId: String
    let serverConstellationId: Int
    let template: ConstellationDTO
    let startedAt: Date
    let endedAt: Date?
    let slotSeconds: Int
    let discoveredStarCount: Int
    let status: SessionStatus
    let memo: SessionMemo?
}

struct FocusSkyLayoutResult {
    let item: FocusSkyLayoutItem
    let session: FocusSession
    let constellation: Constellation
}
