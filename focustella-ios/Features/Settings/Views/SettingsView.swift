import SwiftUI

struct SettingsView: View {
    @AppStorage("highPerformanceMode") private var highPerformanceMode: Bool = false
    @AppStorage("developerMode") private var developerMode: Bool = false
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    
    // 🔥 초기화 버튼 실수 클릭 방지용 얼럿 상태 변수
    @State private var showResetAlert: Bool = false

    var body: some View {
        Form {
            // MARK: - 성능 설정 섹션
            Section {
                Toggle(isOn: $highPerformanceMode) {
                    HStack(spacing: 12) {
                        Image(systemName: highPerformanceMode ? "bolt.fill" : "bolt.slash")
                            .foregroundStyle(highPerformanceMode ? .yellow : .gray)
                            .font(.title3)
                        Text("고사양 모드")
                            .font(.body)
                    }
                }
                .tint(.orange)
            } header: {
                Text("성능 설정")
            } footer: {
                Text("활성화 시 별 반짝임과 별자리 선분 반짝임이 켜집니다. 배터리/발열 사용량이 증가할 수 있습니다.")
            }

            // MARK: - 개발자 섹션
            Section {
                Toggle(isOn: $developerMode) {
                    HStack(spacing: 12) {
                        Image(systemName: developerMode ? "hammer.fill" : "hammer")
                            .foregroundStyle(developerMode ? .orange : .gray)
                            .font(.title3)
                        Text("개발자 모드")
                            .font(.body)
                    }
                }
                .tint(.orange)
            } header: {
                Text("개발자")
            } footer: {
                Text("활성화 시 탭에 별자리 생성/삽입 기능과 세션 디버그 버튼이 표시됩니다.")
            }
            
            // MARK: - 개발자 전용: 데이터 초기화 (developerMode가 켜져 있을 때만 보임)
            if developerMode {
                Section {
                    Button(role: .destructive) {
                        // 🔥 바로 초기화하지 않고 얼럿을 먼저 띄웁니다!
                        showResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("모든 앱 데이터 초기화")
                        }
                    }
                } header: {
                    Text("데이터 관리 (테스트용)")
                } footer: {
                    Text("튜토리얼 시청 기록, 일일 보상 별, 세션 진행 상태를 모두 초기화하고 처음 로그인 화면으로 돌아갑니다.")
                }
            }
        }
        .navigationTitle("Settings")
        // 🔥 초기화 경고 얼럿 뷰
        .alert("앱 데이터 초기화", isPresented: $showResetAlert) {
            Button("취소", role: .cancel) { }
            Button("초기화", role: .destructive) {
                withAnimation {
                    resetAllDeveloperData()
                }
            }
        } message: {
            Text("모든 로컬 데이터가 영구적으로 삭제되며, 강제로 로그아웃됩니다. 정말 초기화하시겠습니까?")
        }
    }
    
    // MARK: - 개발자용 데이터 초기화 로직 (리팩토링)
    private func resetAllDeveloperData() {
        print("🧹 [Settings] 앱 데이터 초기화 시작...")
        
        let defaults = UserDefaults.standard
        
        // 1. 튜토리얼 및 보상 별 초기화 (AppStorage 변수 직접 조작)
        hasSeenTutorial = false
        defaults.removeObject(forKey: "dailyStarsData")
        
        // 2. 일일 세션(투두리스트) 데이터 초기화 (배열을 이용해 깔끔하게 순회 삭제)
        let sessionKeys = [
            "Focustella_ChecklistTemplates",
            "Focustella_ActiveSessionItems",
            "Focustella_LastCompletedDate",
            "Focustella_ActiveSessionStartDate"
        ]
        sessionKeys.forEach { defaults.removeObject(forKey: $0) }
        
        // 3. 강제 로그아웃 (이 값이 변경되면서 즉시 RootView를 통해 LoginView로 쫓겨납니다)
        AuthSessionStore.clear()
        
        print("✅ [Settings] 앱 데이터 초기화 및 로그아웃 완료!")
    }
}

#Preview {
    SettingsView()
}
