import Foundation

final class DailySessionRemoteDataSource {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func saveDailySession(_ payload: DailySessionSaveRequest) async throws {
        _ = try await client.send(EmptyAPIResponse.self, endpoint: SessionEndpoint.saveDaily(payload))
    }

    func fetchDailySessions() async throws -> [FetchedDailySession] {
        try await client.send([FetchedDailySession].self, endpoint: SessionEndpoint.fetchDailyList)
    }
}
