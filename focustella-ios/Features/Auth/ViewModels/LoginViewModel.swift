import SwiftUI
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isLoggedIn: Bool = false
    
    // 매니저 장착
    private let anonymousAuthUseCase = AnonymousAuthUseCase()
    private let signInUseCase = SignInUseCase()
    
    func performMockAppleSignIn(email: String = "") {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                // 🔥 입력받은 이메일이 빈 칸이면 기본 테스트 계정 사용
                let targetEmail = email.trimmingCharacters(in: .whitespaces).isEmpty
                                ? "apple_mock_user@example.com"
                                : email
                let response = try await signInUseCase.execute(email: targetEmail)
                print("📡 [Auth] 테스트 로그인 시도 이메일: \(targetEmail)")
                // 🔥 닉네임 유무에 따라 UserDefaults에 튜토리얼 도장만 찍어둠
                if let nickname = response.user.nickname, !nickname.trimmingCharacters(in: .whitespaces).isEmpty {
                    UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
                } else {
                    UserDefaults.standard.set(false, forKey: "hasSeenTutorial")
                }
                
                // 무조건 로그인 처리! (RootView가 알아서 MainTabView로 보냄)
                withAnimation { self.isLoggedIn = true }
            } catch {
                self.errorMessage = "로그인에 실패했습니다."
            }
            isLoading = false
        }
    }
    
    func loginAsGuest() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let response = try await anonymousAuthUseCase.execute()
        
        // 🔥 게스트도 똑같이 도장만 찍기
        if let nickname = response.user.nickname, !nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
        } else {
            UserDefaults.standard.set(false, forKey: "hasSeenTutorial")
        }
        
        withAnimation { self.isLoggedIn = true }
    }
}
