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
    
    func performMockAppleSignIn() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 더미 이메일로 요청 전송
                let mockEmail = "apple_mock_user@example.com"
                print("📡 [Auth] 임시 애플 로그인 요청: \(mockEmail)")
                
                let response = try await signInUseCase.execute(email: mockEmail)
                print("✅ [Auth] 로그인 성공! 유저ID: \(response.user.id)")
                
                // 🔥 닉네임이 없으면(null) 튜토리얼을 봐야 함!
                if response.user.nickname == nil {
                    UserDefaults.standard.set(true, forKey: "needsTutorial")
                    print("🚀 [Auth] 닉네임 없음: 튜토리얼 진입 필요")
                } else {
                    UserDefaults.standard.set(false, forKey: "needsTutorial")
                    print("🚀 [Auth] 닉네임 존재: 메인 화면 직행")
                }
                
                // 화면 전환 트리거 (RootView 등에서 이 값을 보고 화면을 넘깁니다)
                withAnimation {
                    self.isLoggedIn = true
                }
            } catch {
                print("🚨 [Auth] 로그인 실패: \(error.localizedDescription)")
                self.errorMessage = "로그인에 실패했습니다."
            }
            isLoading = false
        }
    }
    // 🔥 사라졌던 게스트 로그인 함수 부활!
        func loginAsGuest() async throws {
            isLoading = true
            errorMessage = nil
            // 에러가 나든 성공하든 로딩 상태를 false로 돌림
            defer { isLoading = false }
            
            print("📡 [Auth] 게스트 로그인 요청")
            
            let response = try await anonymousAuthUseCase.execute()
            print("✅ [Auth] 게스트 로그인 성공! 유저ID: \(response.user.id)")
            
            // 💡 게스트 로그인도 똑같이 닉네임 유무로 튜토리얼 분기 처리
            if response.user.nickname == nil {
                UserDefaults.standard.set(true, forKey: "needsTutorial")
                print("🚀 [Auth] 닉네임 없음: 튜토리얼 진입 필요")
            } else {
                UserDefaults.standard.set(false, forKey: "needsTutorial")
                print("🚀 [Auth] 닉네임 존재: 메인 화면 직행")
            }
            
            // 뷰에 로그인 성공 알림 (LoginView의 onChange에서 감지해서 화면을 넘김)
            self.isLoggedIn = true
        }
}
