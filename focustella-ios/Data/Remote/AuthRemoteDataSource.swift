import Foundation

final class AuthRemoteDataSource {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func authenticateAnonymously() async throws -> AnonymousAuthData {
        try await client.send(AnonymousAuthData.self, endpoint: AuthEndpoint.anonymous)
    }
}
