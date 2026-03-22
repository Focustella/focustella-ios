import Foundation

final class SignInUseCase {
    private let repository: AuthRepository
    init(repository: AuthRepository = AuthRepositoryImpl()) { self.repository = repository }
    
    func execute(email: String) async throws -> AuthResponseDTO {
        return try await repository.signIn(email: email)
    }
}

final class UpdateNicknameUseCase {
    private let repository: AuthRepository
    init(repository: AuthRepository = AuthRepositoryImpl()) { self.repository = repository }
    
    func execute(nickname: String) async throws {
        try await repository.updateNickname(nickname: nickname)
    }
}

final class AnonymousAuthUseCase {
    private let repository: AuthRepository
    init(repository: AuthRepository = AuthRepositoryImpl()) { self.repository = repository }
    
    func execute() async throws -> AuthResponseDTO {
        return try await repository.authenticateAnonymously()
    }
}

