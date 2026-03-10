import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.11, blue: 0.2), Color(red: 0.03, green: 0.04, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            List {
                Section("친구 추가") {
                    HStack {
                        TextField("친구 아이디 입력", text: $viewModel.newFriendID)
                        Button("요청") {
                            viewModel.sendFriendRequest()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.newFriendID.isEmpty)
                    }
                }

                if !viewModel.pendingRequests.isEmpty {
                    Section("받은 친구 요청") {
                        ForEach(viewModel.pendingRequests) { request in
                            HStack {
                                Text(request.senderName)
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
                    }
                }

                Section("내 친구 (\(viewModel.friends.count))") {
                    if viewModel.friends.isEmpty {
                        Text("아직 추가된 친구가 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.friends) { friend in
                            HStack {
                                Text(friend.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Friends")
        .onAppear {
            viewModel.fetchFriends()
            viewModel.fetchRequests()
        }
    }
}

#Preview {
    NavigationStack {
        FriendsView()
    }
}
