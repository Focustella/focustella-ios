import SwiftUI

struct MainTabView: View {
    private enum Tab: Hashable {
        case mySky
        case dev
        case friends
        case settings
    }

    @AppStorage("isDarkTheme") private var isDarkTheme: Bool = true
    @AppStorage("developerMode") private var developerMode: Bool = false

    var body: some View {
        TabView {
            NavigationStack {
                MySkyView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tag(Tab.mySky)
            .tabItem {
                Label("MySky", systemImage: "sparkles")
            }

            if developerMode {
                NavigationStack {
                    DevConstellationStudioView()
                }
                .tag(Tab.dev)
                .tabItem {
                    Label("Constellation", systemImage: "wand.and.stars")
                }
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
