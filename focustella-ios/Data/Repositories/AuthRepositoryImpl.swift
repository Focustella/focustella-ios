import Foundation

final class AuthRepositoryImpl: AuthRepository {
    private let remoteDataSource: AuthRemoteDataSource

    init(remoteDataSource: AuthRemoteDataSource = AuthRemoteDataSourceImpl()) {
        self.remoteDataSource = remoteDataSource
    }

    func authenticateAnonymously() async throws -> AuthResponseDTO {
        let response = try await remoteDataSource.authenticateAnonymously()
        saveSession(response: response)
        return response
    }

    func signIn(email: String) async throws -> AuthResponseDTO {
        let response = try await remoteDataSource.signIn(email: email)
        saveSession(response: response)
        return response
    }

    func updateNickname(nickname: String) async throws {
        _ = try await remoteDataSource.updateNickname(nickname: nickname)
    }
    
    private func saveSession(response: AuthResponseDTO) {
            // 🚨 중요: 새로 추가된 닉네임과 유저코드도 같이 넘겨줍니다!
            AuthSessionStore.save(
                accessToken: response.accessToken,
                userId: response.user.id,
                seed: Int64(response.user.seed),
                nickname: response.user.nickname, // 🔥 새로 추가!
                userCode: response.user.userCode  // 🔥 새로 추가!
            )
            
            print("✅ [Auth] 세션 저장 성공! (토큰: \(response.accessToken.prefix(8))...)")
        }
}
