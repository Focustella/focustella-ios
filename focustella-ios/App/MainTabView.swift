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
    @AppStorage("developerMode") private var developerMode: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
            
            NavigationStack {
                MySkyView(
                    sessionStore: FocusSessionRuntimeStore(),
                    dailySessionSheetBuilder: { hasSeenTutorial in
                        AnyView(DailySessionView(hasSeenTutorial: hasSeenTutorial))
                    }
                )
                .ignoresSafeArea(edges: .top)
                .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Image(systemName: "sparkles")
                Text("MySky")
            }
            .tag(Tab.mySky)

            if developerMode {
                NavigationStack {
                    DevConstellationStudioView()
                }
                .tabItem {
                    Image(systemName: "wand.and.stars")
                    Text("Dev")
                }
                .tag(Tab.dev)
            }

            NavigationStack {
                FriendsView()
            }
            .tabItem {
                Image(systemName: "person.2")
                Text("Social")
            }
            .tag(Tab.friends)

            NavigationStack {
                MyPageView()
            }
            .tabItem {
                Image(systemName: "gearshape")
                Text("MyPage")
            }
            .tag(Tab.myPage)
        }
        // 우주 배경에 어울리도록 선택된 탭 아이콘을 흰색으로 강조!
        .tint(.white)
    }
}
