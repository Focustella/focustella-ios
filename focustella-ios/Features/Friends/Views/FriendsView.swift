import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.24),
                        Color(red: 0.04, green: 0.06, blue: 0.16),
                        Color(red: 0.02, green: 0.03, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
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
                    
                    // 내 친구 목록 섹션 (develop의 친구 수 표시 기능 합침)
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
                .scrollContentBackground(.hidden) // 리스트 배경 투명화
            }
            .navigationTitle("Friends")
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
    FriendsView()
}
