import Foundation

final class SkyRemoteDataSource {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func fetchMySky() async throws -> SkyResponseDTO {
        try await client.send(SkyResponseDTO.self, endpoint: SkyEndpoint.me)
    }

    func fetchSky(userId: String) async throws -> SkyResponseDTO {
        try await client.send(SkyResponseDTO.self, endpoint: SkyEndpoint.user(userId))
    }
}
