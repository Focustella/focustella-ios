import Foundation

struct FetchMySkyUseCase {
    private let repository: SkyRepository

    init(repository: SkyRepository) {
        self.repository = repository
    }

    func execute() async throws -> SkyResponseDTO {
        try await repository.fetchMySky()
    }
}
