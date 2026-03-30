import Foundation
import Combine
import SwiftUI

@MainActor
final class MyPageViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    
    private let apiClient = APIClient.shared
    
    func deleteAccount() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 🔥 알맹이가 없어서 무조건 catch문으로 빠지게 됩니다. (임시로 String.self 요청)
            let _ = try await apiClient.send(String.self, endpoint: AuthEndpoint.deleteAccount)
            handleDeleteSuccess()
            
        } catch {
            let errorMsg = error.localizedDescription
            
            // 🌟 마법의 예외 처리: 에러 메시지에 [200]이 포함되어 있다면 사실상 성공한 것!
            if errorMsg.contains("[200]") {
                handleDeleteSuccess()
            } else {
                print("🚨 회원 탈퇴 실패: \(errorMsg)")
                self.alertMessage = "회원 탈퇴에 실패했습니다. 잠시 후 다시 시도해 주세요."
                self.showAlert = true
            }
        }
    }
    
    // 탈퇴 성공 시 처리할 로직을 따로 분리했습니다.
    private func handleDeleteSuccess() {
        print("회원 탈퇴 완벽 성공! (data null 예외처리 됨)")
        AuthSessionStore.clear() // 로컬 데이터 날리고 로그인 화면으로!
        // 2. 🔥 앱 플레이 관련 로컬 캐시(우주 화면, 세션) 싹 다 날리기
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: "dailyStarsData")
                let sessionKeys = [
                    "Focustella_ChecklistTemplates",
                    "Focustella_ActiveSessionItems",
                    "Focustella_LastCompletedDate",
                    "Focustella_ActiveSessionStartDate"
                ]
                sessionKeys.forEach { defaults.removeObject(forKey: $0) }
                
                print("🧹 기기에 남은 모든 로컬 데이터 청소 완료!")
    }
}
