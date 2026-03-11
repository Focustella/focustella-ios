import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    // 1. 외부에서 skyModel을 주입받아 배경의 일관성을 유지합니다.
    
    var body: some View {
        
    }
    
    #Preview {
        // Preview에서도 skyModel 주입
        //    FriendsView(skyModel: SkySceneViewModel(seed: 1234))
    }
    
}
