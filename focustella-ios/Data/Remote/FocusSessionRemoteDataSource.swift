import Foundation

final class FocusSessionRemoteDataSource {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func createSession(durationMinutes: Int) async throws -> FocusSessionCreateResponseDTO {
        try await client.send(FocusSessionCreateResponseDTO.self, endpoint: FocusEndpoint.create(durationMinutes: durationMinutes))
    }

    func saveSession(_ request: FocusSessionSaveRequestDTO) async throws {
        _ = try await client.send(EmptyAPIResponse.self, endpoint: FocusEndpoint.save(request))
    }

    func fetchCompletedSessions() async throws -> [FocusSessionRecordDTO] {
        try await client.send([FocusSessionRecordDTO].self, endpoint: FocusEndpoint.list)
    }
}
