import Foundation

protocol FocusSessionRepository {
    func createSession(durationMinutes: Int) async throws -> FocusSessionCreateResponseDTO
    func saveSession(_ request: FocusSessionSaveRequestDTO) async throws
    func fetchCompletedSessions() async throws -> [FocusSessionRecordDTO]
}

protocol FocusTagRepository {
    func fetchTags() async throws -> [UserTagDTO]
    func addTag(name: String) async throws -> UserTagDTO
    func deleteTag(name: String) async throws -> UserTagDTO
}
