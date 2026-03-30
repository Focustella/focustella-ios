// 📂 App/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    private enum Tab: Hashable {
        case mySky
        case dev
        case friends
        case myPage
    }
    
    @State private var selectedTab: Tab = .mySky
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    @AppStorage("developerMode") private var developerMode: Bool = false
    
    // 🔥 가운데 별 버튼의 메뉴 확장 여부
    @State private var isMenuExpanded: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. 메인 뷰 영역
            TabView(selection: $selectedTab) {
                NavigationStack {
                    MySkyView()
                        .toolbar(.hidden, for: .navigationBar)
                        .ignoresSafeArea(.container, edges: [.top])
                }
                .tag(Tab.mySky)
                .toolbar(.hidden, for: .tabBar)

                if developerMode {
                    NavigationStack { DevConstellationStudioView() }
                        .tag(Tab.dev)
                        .toolbar(.hidden, for: .tabBar)
                }

                NavigationStack { FriendsView() }
                    .tag(Tab.friends)
                    .toolbar(.hidden, for: .tabBar)

                NavigationStack { MyPageView() }
                    .tag(Tab.myPage)
                    .toolbar(.hidden, for: .tabBar)
            }
            
            // 2. 커스텀 탭 바 및 확장 메뉴
            if hasSeenTutorial {
                // 🔥 우주 배경 터치 시 열려있는 메뉴 닫기 방어막
                if isMenuExpanded {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isMenuExpanded = false
                            }
                        }
                }
                
                VStack(spacing: 0) {
                    // 🔥 또로롱 튀어 오르는 세션 메뉴
                    if isMenuExpanded {
                        VStack(spacing: 16) {
                            actionButton(title: "집중 세션", icon: "timer", color: .blue) {
                                // 집중 세션 알림 발송
                                NotificationCenter.default.post(name: Notification.Name("ShowFocusSession"), object: nil)
                                closeMenu()
                            }
                            actionButton(title: "일일 계획", icon: "checklist", color: .green) {
                                // 일일 세션 알림 발송
                                NotificationCenter.default.post(name: Notification.Name("ShowDailySession"), object: nil)
                                closeMenu()
                            }
                        }
                        .padding(.bottom, 20)
                        .transition(.scale(scale: 0.1, anchor: .bottom).combined(with: .opacity))
                    }
                    
                    // 🔥 하단 탭 바 (가운데 뚫린 형태)
                    customTabBar
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - 🎨 커스텀 탭 바 본체
    private var customTabBar: some View {
        ZStack {
            // 배경 글래스
            HStack { Spacer() }
                .frame(height: 70)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            
            // 아이콘 배치
            HStack {
                tabItem(icon: "sparkles", tab: .mySky)
                if developerMode { tabItem(icon: "wand.and.stars", tab: .dev) }
                
                Spacer() // 가운데 별을 위한 공간
                
                tabItem(icon: "person.2", tab: .friends)
                tabItem(icon: "gearshape", tab: .myPage)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 10)
            
            // 🌟 대망의 센터 별 버튼 🌟
            Button {
                let generator = UIImpactFeedbackGenerator(style: .rigid)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isMenuExpanded.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 64, height: 64)
                        .shadow(color: .yellow.opacity(0.5), radius: 10, x: 0, y: 5)
                    
                    // 메뉴가 열리면 별이 X자(닫기)로 회전합니다!
                    Image(systemName: "star.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isMenuExpanded ? 144 : 0)) // 144도 회전(별 꼭지점 맞춤)
                        .scaleEffect(isMenuExpanded ? 0.8 : 1.0)
                }
            }
            .offset(y: -25) // 탭 바 위로 반쯤 튀어나오게!
        }
    }
    
    // MARK: - 일반 탭 아이템
    private func tabItem(icon: String, tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = tab }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 24, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.4))
                .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - 팝업 메뉴 버튼
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3.bold())
                Text(title).font(.headline.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(color.opacity(0.8), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private func closeMenu() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isMenuExpanded = false }
    }
}
