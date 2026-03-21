import Foundation

struct CreateFocusSessionUseCase {
    private let repository: FocusSessionRepository

    init(repository: FocusSessionRepository) {
        self.repository = repository
    }

    func execute(durationMinutes: Int) async throws -> FocusSessionCreateResponseDTO {
        try await repository.createSession(durationMinutes: durationMinutes)
    }
}

struct SaveFocusSessionUseCase {
    private let repository: FocusSessionRepository

    init(repository: FocusSessionRepository) {
        self.repository = repository
    }

    func execute(_ request: FocusSessionSaveRequestDTO) async throws {
        try await repository.saveSession(request)
    }
}

struct FetchFocusTagsUseCase {
    private let repository: FocusTagRepository

    init(repository: FocusTagRepository) {
        self.repository = repository
    }

    func execute() async throws -> [UserTagDTO] {
        try await repository.fetchTags()
    }
}

struct AddFocusTagUseCase {
    private let repository: FocusTagRepository

    init(repository: FocusTagRepository) {
        self.repository = repository
    }

    func execute(name: String) async throws -> UserTagDTO {
        try await repository.addTag(name: name)
    }
}

struct DeleteFocusTagUseCase {
    private let repository: FocusTagRepository

    init(repository: FocusTagRepository) {
        self.repository = repository
    }

    func execute(name: String) async throws -> UserTagDTO {
        try await repository.deleteTag(name: name)
    }
}
