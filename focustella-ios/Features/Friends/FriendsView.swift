import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @StateObject private var skyModel = SkySceneViewModel(seed: 1234)
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. 별자리 배경 깔기
                SkyView(model: skyModel, showsTitle: false, showsTwinkle: true, isInteractive: false)
                    .ignoresSafeArea()
                
                // 2. 친구 목록 레이어
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
                        // 하얀색 대신 기본 보조색(회색)으로 변경
                        Text("친구 추가").foregroundStyle(.secondary)
                    }
                    // 리스트 셀 배경을 완전히 투명하게 하거나, 아주 옅은 흰색으로 설정
                    .listRowBackground(Color.clear)
                    
                    // 받은 친구 요청 섹션
                    if !viewModel.pendingRequests.isEmpty {
                        Section {
                            ForEach(viewModel.pendingRequests) { request in
                                HStack {
                                    Text(request.senderName)
                                        .foregroundStyle(.primary) // 기본 텍스트 색상(검정)
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
                                        .foregroundStyle(.primary) // 검정 글씨
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
            // .toolbarColorScheme(.dark, for: .navigationBar) <- 타이틀을 하얗게 만들던 주범 삭제!
            .onAppear {
                viewModel.fetchFriends()
                viewModel.fetchRequests()
            }
        }
    }
}

#Preview {
    FriendsView()
}
