import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    // 1. SessionHomeView처럼 외부에서 동일한 skyModel을 주입받도록 변경합니다.
    @ObservedObject var skyModel: SkySceneViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 별자리 배경 깔기 (SessionHomeView와 완전히 동일하게 설정)
                SkyView(
                    model: skyModel,
                    showsTitle: false,
                    showsTwinkle: true,
                    isInteractive: false
                )
                .ignoresSafeArea()
                
                // 친구 목록 레이어
                List {
                    // 친구 추가 섹션
                    Section {
                        HStack {
                            TextField("친구 아이디 입력", text: $viewModel.newFriendID)
                                .textFieldStyle(.plain)
                            
                            Button("요청") {
                                viewModel.sendFriendRequest()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.newFriendID.isEmpty)
                        }
                    } header: {
                        Text("친구 추가").foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    
                    // 받은 친구 요청 섹션
                    if !viewModel.pendingRequests.isEmpty {
                        Section {
                            ForEach(viewModel.pendingRequests) { request in
                                HStack {
                                    Text(request.senderName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Button("수락") {
                                        viewModel.respondToRequest(requestID: request.id, isAccepted: true)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.green)
                                    
                                    Button("거절") {
                                        viewModel.respondToRequest(requestID: request.id, isAccepted: false)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                            }
                        } header: {
                            Text("받은 친구 요청").foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                    
                    // 내 친구 목록 섹션
                    Section {
                        if viewModel.friends.isEmpty {
                            Text("아직 추가된 친구가 없습니다.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.friends) { friend in
                                HStack {
                                    Text(friend.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    print("\(friend.name) 의 별자리 보기 탭됨")
                                }
                            }
                        }
                    } header: {
                        Text("내 친구 (\(viewModel.friends.count))").foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Friends")
            // 2. SessionHomeView와 동일하게 하단 여백을 추가하여 리스트가 탭바에 가리지 않게 합니다.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 52)
            }
            .onAppear {
                viewModel.fetchFriends()
                viewModel.fetchRequests()
            }
        }
    }
}

#Preview {
    // Preview에서도 skyModel을 주입해 줍니다.
    FriendsView(skyModel: SkySceneViewModel(seed: 1234))
}
