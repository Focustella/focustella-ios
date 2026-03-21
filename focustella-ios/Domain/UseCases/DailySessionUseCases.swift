import Foundation

struct SaveDailySessionUseCase {
    private let repository: DailySessionRepository

    init(repository: DailySessionRepository) {
        self.repository = repository
    }

    func execute(_ payload: DailySessionSaveRequest) async throws {
        try await repository.saveDailySession(payload)
    }
}

struct FetchDailySessionsUseCase {
    private let repository: DailySessionRepository

    init(repository: DailySessionRepository) {
        self.repository = repository
    }

    func execute() async throws -> [FetchedDailySession] {
        try await repository.fetchDailySessions()
    }
}
