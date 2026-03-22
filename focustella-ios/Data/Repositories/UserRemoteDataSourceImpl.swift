import Foundation

final class UserRemoteDataSourceImpl: UserRemoteDataSource {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func searchUsers(keyword: String) async throws -> [UserSearchDTO] {
        // 🌟 마법의 한 줄: 껍데기 DTO 없이 배열 타입([UserSearchDTO].self)만 딱 넘깁니다!
        return try await client.send(
            [UserSearchDTO].self,
            endpoint: UserEndpoint.search(keyword)
        )
    }
}
