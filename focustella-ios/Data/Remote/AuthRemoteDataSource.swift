import Foundation

protocol AuthRemoteDataSource {
    func authenticateAnonymously() async throws -> AuthResponseDTO
    func signIn(email: String) async throws -> AuthResponseDTO
    func updateNickname(nickname: String) async throws -> EmptyData
}

final class AuthRemoteDataSourceImpl: AuthRemoteDataSource {
    private let apiClient = APIClient.shared

    func authenticateAnonymously() async throws -> AuthResponseDTO {
        let endpoint = AuthEndpoint.anonymous
        return try await apiClient.send(endpoint: endpoint)
    }

    func signIn(email: String) async throws -> AuthResponseDTO {
        let endpoint = AuthEndpoint.signIn(email: email)
        return try await apiClient.send(endpoint: endpoint)
    }

    func updateNickname(nickname: String) async throws -> EmptyData {
        let endpoint = AuthEndpoint.updateNickname(nickname: nickname)
        return try await apiClient.send(endpoint: endpoint)
    }
}
