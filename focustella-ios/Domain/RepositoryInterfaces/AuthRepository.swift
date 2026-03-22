import Foundation

protocol AuthRepository {
    func authenticateAnonymously() async throws -> AuthResponseDTO
    func signIn(email: String) async throws -> AuthResponseDTO
    func updateNickname(nickname: String) async throws
}
