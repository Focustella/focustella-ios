import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    private let loginAnonymouslyUseCase: LoginAnonymouslyUseCase

    @Published var isGuestLoading = false

    init(loginAnonymouslyUseCase: LoginAnonymouslyUseCase) {
        self.loginAnonymouslyUseCase = loginAnonymouslyUseCase
    }

    convenience init() {
        self.init(
            loginAnonymouslyUseCase: LoginAnonymouslyUseCase(
                repository: AuthRepositoryImpl()
            )
        )
    }

    func loginAsGuest() async throws {
        isGuestLoading = true
        defer { isGuestLoading = false }

        let authData = try await loginAnonymouslyUseCase.execute()
        AuthSessionStore.save(
            accessToken: authData.accessToken,
            userId: authData.user.id,
            seed: authData.user.seed
        )
    }
}
