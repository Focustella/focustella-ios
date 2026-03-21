import Foundation

final class SkyRepositoryImpl: SkyRepository {
    private let remoteDataSource: SkyRemoteDataSource

    init(remoteDataSource: SkyRemoteDataSource = SkyRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchMySky() async throws -> SkyResponseDTO {
        try await remoteDataSource.fetchMySky()
    }

    func fetchSky(userId: String) async throws -> SkyResponseDTO {
        try await remoteDataSource.fetchSky(userId: userId)
    }
}
