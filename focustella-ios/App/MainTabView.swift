import SwiftUI

struct MainTabView: View {
    @StateObject private var skyModel = SkySceneViewModel(seed: 12345)

    var body: some View {
        TabView {
            NavigationStack {
                SkyView(model: skyModel, showsTitle: true, showsTwinkle: true, isInteractive: true)
            }
            .tabItem {
                Label("Sky", systemImage: "sparkles")
            }

            NavigationStack {
                SessionHomeView(skyModel: skyModel)
            }
            .tabItem {
                Label("Session", systemImage: "timer")
            }

            NavigationStack {
                FriendsView()
            }
            .tabItem {
                Label("Friends", systemImage: "person.2")
            }
        }
    }
}

#Preview {
    MainTabView()
}
