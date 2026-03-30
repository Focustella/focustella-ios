// 📂 Features/MyPage/Views/MyPageView.swift
import SwiftUI

struct MyPageView: View {
    @StateObject private var viewModel = MyPageViewModel()
    
    @AppStorage("highPerformanceMode") private var highPerformanceMode: Bool = false
    @AppStorage("developerMode") private var developerMode: Bool = false
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    @AppStorage("mySkyBackgroundVariant") private var backgroundVariant: MySkyBackgroundVariant = .focusStar
    
    @State private var showResetAlert: Bool = false
    @State private var showDeleteAlert: Bool = false
    
    // 복사 완료 토스트 알림용 상태 변수
    @State private var showCopyToast: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 1. 우주 배경
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
                
                ScrollView {
                    VStack(spacing: 24) { // 카드 사이 간격을 조금 더 넓게(24)
                        
                        // MARK: - 1. 프로필 카드 (가장 큼!)
                        profileCard
                        
                        // MARK: - 2. 계정 설정 카드
                        SettingCard(title: "계정 설정") {
                            // 닉네임 변경
                            SettingRowButton(icon: "pencil", title: "닉네임 변경", color: .white) {
                                print("닉네임 변경 탭됨 (미구현)")
                            }
                            
                            Divider().background(Color.white.opacity(0.2)).padding(.vertical, 4)
                            
                            // 회원 탈퇴
                            SettingRowButton(icon: "person.crop.circle.badge.xmark", title: "회원 탈퇴", color: .red) {
                                showDeleteAlert = true
                            }
                        }
                        
                        // MARK: - 3. 활동 카드 (기록, 업적, 진행도)
                        if developerMode {
                                                    SettingCard(title: "내 활동") {
                                                        SettingRowButton(icon: "clock.fill", title: "기록", color: .white) { }
                                                        Divider().background(Color.white.opacity(0.2)).padding(.vertical, 4)
                                                        SettingRowButton(icon: "medal.fill", title: "업적", color: .yellow) { }
                                                        Divider().background(Color.white.opacity(0.2)).padding(.vertical, 4)
                                                        SettingRowButton(icon: "chart.bar.fill", title: "진행도", color: .green) { }
                                                    }
                                                    // 🌟 마법의 한 줄: 카드가 나타나고 사라질 때 스르륵 트랜지션 효과!
                                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                                }
                        // MARK: - 4. 앱 설정 카드 (기존 설정)
                        SettingCard(title: "설정") {
                            Toggle(isOn: $highPerformanceMode) {
                                HStack(spacing: 12) {
                                    Image(systemName: highPerformanceMode ? "bolt.fill" : "bolt.slash")
                                        .foregroundStyle(highPerformanceMode ? .yellow : .gray)
                                        .frame(width: 24)
                                        .font(.title3) // 크기 통일
                                    Text("고사양 모드")
                                        .font(.body)
                                        .foregroundStyle(.white)
                                }
                            }
                            .tint(.orange)
                            .padding(.vertical, 8) // 높이 통일
                            
                            Divider().background(Color.white.opacity(0.2)).padding(.vertical, 4)
                            
                            Toggle(isOn: $developerMode) {
                                HStack(spacing: 12) {
                                    Image(systemName: developerMode ? "hammer.fill" : "hammer")
                                        .foregroundStyle(developerMode ? .orange : .gray)
                                        .frame(width: 24)
                                        .font(.title3) // 크기 통일
                                    Text("개발자 모드")
                                        .font(.body)
                                        .foregroundStyle(.white)
                                }
                            }
                            .tint(.orange)
                            .padding(.vertical, 8) // 높이 통일
                            
                            Divider().background(Color.white.opacity(0.2)).padding(.vertical, 4)
                            
                            // 🔥 이제 누구나 사용할 수 있는 하늘 배경 설정!
                            HStack(spacing: 12) {
                                Image(systemName: "moon.stars.fill")
                                    .foregroundStyle(.cyan)
                                    .frame(width: 24)
                                    .font(.title3)
                                
                                Text("하늘 배경")
                                    .font(.body)
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                Picker("배경 선택", selection: $backgroundVariant) {
                                    ForEach(MySkyBackgroundVariant.allCases, id: \.self) { variant in
                                        Text(variant.title).tag(variant)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(.white.opacity(0.6))
                            }
                            .padding(.vertical, 8)
                            
                            if developerMode {
                                Divider().background(Color.white.opacity(0.2)).padding(.vertical, 4)
                                SettingRowButton(icon: "trash.circle.fill", title: "모든 앱 데이터 초기화 (테스트용)", color: .red) {
                                    showResetAlert = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: developerMode)
                }
            }
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.inline)
            
            // 각종 Alert 및 오버레이 유지...
            .alert("앱 데이터 초기화", isPresented: $showResetAlert) {
                Button("취소", role: .cancel) { }
                Button("초기화", role: .destructive) {
                    withAnimation { resetAllDeveloperData() }
                }
            } message: {
                Text("모든 로컬 데이터가 영구적으로 삭제되며, 강제로 로그아웃됩니다. 정말 초기화하시겠습니까?")
            }
            .alert("회원 탈퇴", isPresented: $showDeleteAlert) {
                Button("취소", role: .cancel) { }
                Button("탈퇴하기", role: .destructive) {
                    Task { await viewModel.deleteAccount() }
                }
            } message: {
                Text("정말로 탈퇴하시겠습니까? 지금까지 모은 별자리와 모든 데이터가 삭제되며 복구할 수 없습니다.")
            }
            .alert("알림", isPresented: $viewModel.showAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        ProgressView("처리 중...")
                            .padding()
                            .background(Color(white: 0.2))
                            .cornerRadius(10)
                            .foregroundStyle(.white)
                    }
                }
            }
            // 🔥 복사 완료 토스트 메시지 오버레이
            .overlay(alignment: .top) {
                if showCopyToast {
                    Text("해시태그가 복사되었습니다!")
                        .font(.subheadline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 10)
                }
            }
        }
    }
        // MARK: - 🎨 프로필 카드 (가장 큰 칸)
        private var profileCard: some View {
            VStack(spacing: 20) {
                // 닉네임 # 해시태그
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(AuthSessionStore.myNickname)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Text("#\(AuthSessionStore.myUserCode)")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                // 복사 & 공유 버튼 그룹
                HStack(spacing: 16) {
                    // 1. 기존에 만든 복사 버튼 (유지)
                    Button {
                        copyToClipboard(text: AuthSessionStore.myUserCode)
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("코드 복사")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                    }
                    
                    // 🔥 2. 새로 추가한 ShareLink (에브리타임 스타일 공유!)
                    let shareText = """
                    Focustella에서 \(AuthSessionStore.myNickname)님이 친구가 되고 싶어해요. 
                    친구를 맺은 후 함께 우주를 채워보세요! ✨
                    
                    초대 링크:
                    https://focustella.com/invite?code=\(AuthSessionStore.myUserCode)
                    """
                    
                    ShareLink(item: shareText) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("공유하기")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                    }
                }
            }
            .padding(20) // 기존 24에서 20으로 변경 (SettingCard와 통일)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    
    // MARK: - 클립보드 복사 액션
    private func copyToClipboard(text: String) {
        UIPasteboard.general.string = text
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success) // 진동 피드백
        
        withAnimation(.spring()) { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring()) { showCopyToast = false }
        }
    }

    private func resetAllDeveloperData() {
        let defaults = UserDefaults.standard
        hasSeenTutorial = false
        defaults.removeObject(forKey: "dailyStarsData")
        let sessionKeys = ["Focustella_ChecklistTemplates", "Focustella_ActiveSessionItems", "Focustella_LastCompletedDate", "Focustella_ActiveSessionStartDate"]
        sessionKeys.forEach { defaults.removeObject(forKey: $0) }
        AuthSessionStore.clear()
    }
}

// MARK: - 🎨 카드 UI 컴포넌트 (description 제거, 깔끔한 그룹핑용)
struct SettingCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { // 제목과 카드 사이 간격 소폭 조정
            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .padding(20) // 내부 패딩 20으로 통일
            .background(Color.white.opacity(0.08)) // 투명도 통일
            .cornerRadius(20) // 코너 곡률 20으로 통일
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
}


// MARK: - 🎨 재사용 가능한 버튼 Row 컴포넌트
struct SettingRowButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24) // 아이콘 정렬 맞추기
                    .font(.title3)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(color == .white ? .white : color)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle()) // 빈 공간 터치 인식
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MyPageView()
}
