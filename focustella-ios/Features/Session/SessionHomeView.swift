import SwiftUI

struct SessionHomeView: View {
    @ObservedObject var skyModel: SkySceneViewModel

    var body: some View {
        ZStack {
            SkyView(
                model: skyModel,
                showsTitle: false,
                showsTwinkle: true,
                isInteractive: false
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                NavigationLink {
                    DailySessionView()
                } label: {
                    Text("일일 세션")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1.0, green: 0.97, blue: 0.8))

                NavigationLink {
                    FocusSessionView()
                } label: {
                    Text("집중 세션")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color(red: 1.0, green: 0.97, blue: 0.8))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 52)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        SessionHomeView(skyModel: SkySceneViewModel(seed: 1234))
    }
}
