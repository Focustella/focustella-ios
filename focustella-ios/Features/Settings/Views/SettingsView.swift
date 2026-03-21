import SwiftUI

struct SettingsView: View {
    @AppStorage("highPerformanceMode") private var highPerformanceMode: Bool = false
    @AppStorage("developerMode") private var developerMode: Bool = false
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false

    var body: some View {
        Form {
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
            if developerMode {
                Section {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            resetAllDeveloperData()
                                        }
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
            // 🔥 테스트용 로그아웃 버튼 (항상 보이도록 가장 아래에 추가)
            Section {
                Button("튜토리얼 다시 보기") {
                        withAnimation {
                            hasSeenTutorial = false // 👈 다시 TutorialView로 쫓겨남(?)
                        }
                    }
                Button(role: .destructive) {
                    withAnimation {
                        AuthSessionStore.clear()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("로그아웃")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
    // MARK: - 개발자용 데이터 초기화 로직
        private func resetAllDeveloperData() {
            // 1. 튜토리얼 및 보상 별 초기화
            UserDefaults.standard.set(false, forKey: "hasSeenTutorial")
            UserDefaults.standard.set("", forKey: "dailyStarsData")
            
            // 2. 일일 세션(투두리스트) 데이터 초기화
            UserDefaults.standard.removeObject(forKey: "Focustella_ChecklistTemplates")
            UserDefaults.standard.removeObject(forKey: "Focustella_ActiveSessionItems")
            UserDefaults.standard.removeObject(forKey: "Focustella_LastCompletedDate")
            UserDefaults.standard.removeObject(forKey: "Focustella_ActiveSessionStartDate")
            
            // 3. 강제 로그아웃 (이 값이 변경되면서 즉시 RootView를 통해 LoginView로 쫓겨납니다)
            AuthSessionStore.clear()
        }
}

#Preview {
    SettingsView()
}
