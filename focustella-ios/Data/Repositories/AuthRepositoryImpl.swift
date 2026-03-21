import Foundation

final class AuthRepositoryImpl: AuthRepository {
    private let remoteDataSource: AuthRemoteDataSource

    init(remoteDataSource: AuthRemoteDataSource = AuthRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func authenticateAnonymously() async throws -> AnonymousAuthData {
        try await remoteDataSource.authenticateAnonymously()
    }
}
