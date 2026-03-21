import Foundation

protocol DailySessionRepository {
    func saveDailySession(_ payload: DailySessionSaveRequest) async throws
    func fetchDailySessions() async throws -> [FetchedDailySession]
}
