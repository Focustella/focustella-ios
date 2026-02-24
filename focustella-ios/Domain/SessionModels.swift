import Foundation
import Combine

enum SessionType: String, Codable, Hashable {
    case daily
    case focus
}

struct DailySessionRecord: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let studyMode: String

    init(id: UUID = UUID(), date: Date, studyMode: String) {
        self.id = id
        self.date = date
        self.studyMode = studyMode
    }
}

struct FocusSessionRecord: Identifiable, Hashable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let targetMinutes: Int
    let actualSeconds: Int

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        targetMinutes: Int,
        actualSeconds: Int
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.targetMinutes = targetMinutes
        self.actualSeconds = actualSeconds
    }
}

@MainActor
final class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published private(set) var dailyRecords: [DailySessionRecord] = []
    @Published private(set) var focusRecords: [FocusSessionRecord] = []

    func addDailyRecord(studyMode: String, date: Date = Date()) {
        let record = DailySessionRecord(date: date, studyMode: studyMode)
        dailyRecords.insert(record, at: 0)
    }

    func addFocusRecord(
        startedAt: Date,
        endedAt: Date,
        targetMinutes: Int,
        actualSeconds: Int
    ) {
        let record = FocusSessionRecord(
            startedAt: startedAt,
            endedAt: endedAt,
            targetMinutes: targetMinutes,
            actualSeconds: actualSeconds
        )
        focusRecords.insert(record, at: 0)
    }
}

