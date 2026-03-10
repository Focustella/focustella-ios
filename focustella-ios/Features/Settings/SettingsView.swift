import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkTheme") private var isDarkTheme: Bool = true
    @AppStorage("highPerformanceMode") private var highPerformanceMode: Bool = false
    @AppStorage("developerMode") private var developerMode: Bool = false

    var body: some View {
        Form {
            Section {
                // 💡 가장 깔끔한 기본 Toggle 사용
                Toggle(isOn: $isDarkTheme) {
                    HStack(spacing: 12) {
                        Image(systemName: isDarkTheme ? "moon.stars.fill" : "sun.max.fill")
                            .foregroundStyle(isDarkTheme ? .yellow : .orange)
                            .font(.title3)
                        
                        Text("우주 다크 테마")
                            .font(.body)
                    }
                }
                .tint(.indigo)
            } header: {
                Text("화면 설정")
            } footer: {
                Text("포커스텔라의 전체 배경과 글자 색상이 테마에 맞춰 자동으로 변경됩니다.")
            }

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
        }
        .navigationTitle("Settings")
    }
}
