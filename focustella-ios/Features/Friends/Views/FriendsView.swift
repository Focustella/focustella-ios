import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. 조립품: 배경
                backgroundGradient
                
                List {
                    // 🔥 몸통이 엄청 깔끔해졌죠?
                    if !viewModel.searchText.isEmpty {
                        // 2. 조립품: 검색 결과 화면
                        searchResultSection
                    } else {
                        // 3. 조립품: 기본 친구 목록 화면
                        defaultFriendsSection
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.fetchFriends()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.white)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "닉네임 또는 해시태그(#) 검색")
            .onSubmit(of: .search) {
                viewModel.executeSearch()
            }
            // 🔥 최신 iOS 17 문법으로 안정성 확보
            .onChange(of: viewModel.searchText) { oldValue, newValue in
                if newValue.isEmpty {
                    viewModel.searchResults.removeAll()
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 52)
            }
            .onAppear {
                viewModel.fetchFriendsIfNeeded()
            }
        }
        .alert("알림", isPresented: $viewModel.showAlert) {
                    Button("확인", role: .cancel) { }
                } message: {
                    Text(viewModel.alertMessage)
                }
    }
    
    // MARK: - 🧩 UI 조립 부품들
    
    private var backgroundGradient: some View {
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
    }
    
    @ViewBuilder
    private var searchResultSection: some View {
        Section("검색 결과") {
            if viewModel.searchResults.isEmpty {
                Text("검색 결과가 없습니다.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.searchResults, id: \.id) { user in
                    HStack {
                        // Text() + Text() 대신 안전하게 HStack으로 묶음 (에러 방지용)
                        HStack(spacing: 0) {
                            Text("\(user.nickname)").bold()
                            Text("#\(user.userCode)").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("친구요청") {
                            viewModel.sendFriendRequest(to: user.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.small)
                    }
                    .listRowBackground(Color.white.opacity(0.1))
                }
            }
        }
    }
    
    @ViewBuilder
    private var defaultFriendsSection: some View {
        // 1. 내 프로필 정보
        Section {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("내 아이디").font(.caption).foregroundStyle(.secondary)
                    Text(viewModel.myProfileText).font(.headline).foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.white.opacity(0.1))
        
        // 2. 받은 친구 요청
        if !viewModel.pendingRequests.isEmpty {
            Section {
                ForEach(viewModel.pendingRequests) { request in
                    HStack {
                        Text(request.senderName).foregroundStyle(.primary)
                        Spacer()
                        Button("수락") { viewModel.respondToRequest(requestID: request.id, isAccepted: true) }
                            .buttonStyle(.bordered).tint(.green)
                        Button("거절") { viewModel.respondToRequest(requestID: request.id, isAccepted: false) }
                            .buttonStyle(.bordered).tint(.red)
                    }
                    .listRowBackground(Color.white.opacity(0.1))
                }
            } header: {
                Text("받은 친구 요청").foregroundStyle(.secondary)
            }
        }
        
        // 3. 내 친구 목록
        Section {
            if viewModel.friends.isEmpty {
                Text("아직 추가된 친구가 없습니다.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.friends) { friend in
                    HStack {
                        Text(friend.name).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { print("\(friend.name) 탭됨") }
                    .listRowBackground(Color.white.opacity(0.1))
                }
            }
        } header: {
            Text("내 친구 (\(viewModel.friends.count))").foregroundStyle(.secondary)
        }
    }
}

#Preview {
    FriendsView()
}
