import SwiftUI

struct SettingsView: View {
    @AppStorage("highPerformanceMode") private var highPerformanceMode: Bool = false
    @AppStorage("developerMode") private var developerMode: Bool = false
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false // 👈 로그인 상태
    
    // 🔥 서버 IP를 저장할 AppStorage 추가 (기본값: localhost)
    @AppStorage("serverIP") private var serverIP: String = "localhost"
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
            
            // 🔥 개발자 모드가 켜져 있을 때만 보이는 네트워크 설정 섹션
            if developerMode {
                Section {
                    HStack {
                        Image(systemName: "network")
                            .foregroundStyle(.blue)
                            .font(.title3)
                        
                        Text("서버 IP")
                            .layoutPriority(1)
                        
                        Spacer()
                        
                        // IP 입력 필드
                        TextField("예: 192.168.0.10", text: $serverIP)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .keyboardType(.numbersAndPunctuation) // IP 입력하기 편한 키보드
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    // 편의 기능: 다시 localhost로 돌리는 버튼
                    if serverIP != "localhost" && serverIP != "127.0.0.1" {
                        Button {
                            withAnimation {
                                serverIP = "localhost"
                            }
                        } label: {
                            Text("localhost로 초기화")
                                .foregroundStyle(.red)
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Text("네트워크 설정 (테스트용)")
                } footer: {
                    Text("실기기 테스트 시 컴퓨터의 로컬 IP(IPv4)를 입력하세요. 시뮬레이터는 기본값(localhost)을 사용합니다.")
                }
                // 🚀 여기에 데이터 초기화 섹션을 추가합니다!
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
                        isLoggedIn = false
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
            isLoggedIn = false
        }
}

#Preview {
    SettingsView()
}
