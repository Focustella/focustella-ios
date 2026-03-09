import SwiftUI

struct MainTabView: View {
    private enum Tab: Hashable {
        case sky
        case session
        case friends
        case settings
    }

    @StateObject private var skyModel = SkySceneViewModel(seed: 12345)
    @AppStorage("isDarkTheme") private var isDarkTheme: Bool = true
    
    var body: some View {
        TabView {
            NavigationStack {
                ZStack(alignment: .topLeading) {
                    SkyView(
                        model: skyModel,
                        showsTitle: false,
                        showsTwinkle: true,
                        isInteractive: true
                    )
                    .ignoresSafeArea()

                    Text("Sky")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 44)
                        .padding(.horizontal, 24)
                }
                .toolbar(.hidden, for: .navigationBar)
            }
                .tag(Tab.sky)
                .tabItem {
                    Label("Sky", systemImage: "sparkles")
                }

            NavigationStack {
                SessionHomeView(skyModel: skyModel)
            }
                .tag(Tab.session)
                .tabItem {
                    Label("Session", systemImage: "timer")
                }

            NavigationStack {
                FriendsView(skyModel: skyModel)
            }
                .tag(Tab.friends)
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
                
            NavigationStack {
                SettingsView()
            }
                .tag(Tab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .preferredColorScheme(isDarkTheme ? .dark : .light)
    }
}
