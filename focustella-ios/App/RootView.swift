// 📂 RootView.swift
import SwiftUI

struct RootView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    
    var body: some View {
        Group {
            if isLoggedIn {
                // 로그인 완료 시 무조건 메인 화면으로 이동!
                // (튜토리얼 여부는 MySkyView가 알아서 판단해서 오버레이를 띄웁니다)
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isLoggedIn)
    }
}

#Preview {
    RootView()
}
