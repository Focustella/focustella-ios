import Foundation

final class DailySessionRepositoryImpl: DailySessionRepository {
    private let remoteDataSource: DailySessionRemoteDataSource

    init(remoteDataSource: DailySessionRemoteDataSource = DailySessionRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func saveDailySession(_ payload: DailySessionSaveRequest) async throws {
        try await remoteDataSource.saveDailySession(payload)
    }

    func fetchDailySessions() async throws -> [FetchedDailySession] {
        try await remoteDataSource.fetchDailySessions()
    }
}
