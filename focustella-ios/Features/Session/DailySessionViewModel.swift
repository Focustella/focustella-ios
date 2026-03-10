import Foundation
import Combine

@MainActor
final class DailySessionViewModel: ObservableObject {
    @Published var selectedStudyMode: String = "수학문제"
    @Published private(set) var records: [DailySessionRecord] = []

    private let store: SessionStore

    init(store: SessionStore) {
        self.store = store
        self.records = store.dailyRecords
    }

    convenience init() {
        self.init(store: .shared)
    }

    func completeDailySession() {
        store.addDailyRecord(studyMode: selectedStudyMode)
        records = store.dailyRecords
    }
}
