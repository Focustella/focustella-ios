import Foundation

final class FocusSessionRepositoryImpl: FocusSessionRepository {
    private let remoteDataSource: FocusSessionRemoteDataSource

    init(remoteDataSource: FocusSessionRemoteDataSource = FocusSessionRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func createSession(durationMinutes: Int) async throws -> FocusSessionCreateResponseDTO {
        try await remoteDataSource.createSession(durationMinutes: durationMinutes)
    }

    func saveSession(_ request: FocusSessionSaveRequestDTO) async throws {
        try await remoteDataSource.saveSession(request)
    }

    func fetchCompletedSessions() async throws -> [FocusSessionRecordDTO] {
        try await remoteDataSource.fetchCompletedSessions()
    }
}

final class FocusTagRepositoryImpl: FocusTagRepository {
    private let remoteDataSource: FocusTagRemoteDataSource

    init(remoteDataSource: FocusTagRemoteDataSource = FocusTagRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchTags() async throws -> [UserTagDTO] {
        try await remoteDataSource.fetchTags()
    }

    func addTag(name: String) async throws -> UserTagDTO {
        try await remoteDataSource.addTag(name: name)
    }

    func deleteTag(name: String) async throws -> UserTagDTO {
        try await remoteDataSource.deleteTag(name: name)
    }
}
