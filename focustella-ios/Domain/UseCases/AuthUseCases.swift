import Foundation

struct LoginAnonymouslyUseCase {
    private let repository: AuthRepository

    init(repository: AuthRepository) {
        self.repository = repository
    }

    func execute() async throws -> AnonymousAuthData {
        try await repository.authenticateAnonymously()
    }
}
