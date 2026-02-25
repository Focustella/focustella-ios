import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkTheme") private var isDarkTheme: Bool = true

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
        }
        .navigationTitle("Settings")
    }
}
