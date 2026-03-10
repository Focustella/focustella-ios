import SwiftUI

struct SessionHomeView: View {
    @ObservedObject var skyModel: SkySceneViewModel
    
    // 🔥 일일 세션 바텀 시트를 제어하기 위한 상태 변수 추가
    @State private var showingDailySession = false

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
                // 🔥 NavigationLink를 Button으로 변경
                Button {
                    showingDailySession = true
                } label: {
                    Text("일일 세션")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1.0, green: 0.97, blue: 0.8))

                // 집중 세션은 기존과 동일하게 유지 (필요 시 동일하게 변경 가능)
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
        // 🔥 상태 변수가 true가 되면 아래에서 위로 뷰를 띄움
        .sheet(isPresented: $showingDailySession) {
            DailySessionView()
        }
    }
}

#Preview {
    NavigationStack {
        SessionHomeView(skyModel: SkySceneViewModel(seed: 1234))
    }
}
