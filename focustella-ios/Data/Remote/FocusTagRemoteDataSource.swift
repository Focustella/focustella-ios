import Foundation

final class FocusTagRemoteDataSource {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func fetchTags() async throws -> [UserTagDTO] {
        try await client.send([UserTagDTO].self, endpoint: FocusTagEndpoint.list)
    }

    @discardableResult
    func addTag(name: String) async throws -> UserTagDTO {
        let request = UserTagMutationRequestDTO(name: name)
        return try await client.send(UserTagDTO.self, endpoint: FocusTagEndpoint.add(request))
    }

    @discardableResult
    func deleteTag(name: String) async throws -> UserTagDTO {
        let request = UserTagMutationRequestDTO(name: name)
        return try await client.send(UserTagDTO.self, endpoint: FocusTagEndpoint.delete(request))
    }
}
