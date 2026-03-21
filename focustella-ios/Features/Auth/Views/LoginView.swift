// 📂 Features/Auth/Views/LoginView.swift
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()

    @State private var isAnimating = false
    @State private var showGuestAlert = false
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("accessToken") private var accessToken: String = ""
    @AppStorage("userId") private var userId: String = ""
    @AppStorage("userSeed") private var userSeed: Int = 0
    
    var body: some View {
        ZStack {
            // 1. 웅장한 다크 우주 배경
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.15),
                    Color(red: 0.05, green: 0.08, blue: 0.20),
                    Color(red: 0.01, green: 0.02, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 2. 밀도 높은 별과 별자리 배경
            DenseStarFieldView(isAnimating: isAnimating)
            
            // 3. 메인 카피 및 로그인 버튼 영역
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.yellow.opacity(0.8))
                        .padding(.bottom, 8)
                    
                    Text("광활한 우주를")
                        .font(.title2)
                        .fontWeight(.light)
                        .foregroundStyle(.white.opacity(0.9))
                    
                    Text("내 것으로 만드세요")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                
                Spacer()
                
                // 🚀 4-A. 결제 전까지 임시로 사용할 더미 로그인 버튼
                Button {
                    
                } label: {
                    HStack {
                        Image(systemName: "applelogo")
                            .font(.system(size: 20))
                        Text("Sign in with Apple (테스트)")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(100)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

                // 게스트 로그인 문구
                Button {
                    showGuestAlert = true
                } label: {
                    if viewModel.isGuestLoading {
                        ProgressView()
                            .tint(.white.opacity(0.6))
                    } else {
                        Text("게스트로 로그인")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                            .underline()
                    }
                }
                .disabled(viewModel.isGuestLoading)
                .padding(.bottom, 60)

                /*
                // 🔒 4-B. 나중에 개발자 계정 결제 후 주석 해제해서 사용할 진짜 버튼
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleLoginResult(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 56)
                .cornerRadius(100)
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
                */
            }
        }
        .alert("게스트로 로그인", isPresented: $showGuestAlert) {
            Button("계속", role: .destructive) {
                Task { await performGuestLogin() }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("게스트로 로그인하면 앱 삭제 시 데이터를 보존할 수 없습니다. 계속하시겠습니까?")
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - 게스트 로그인
    private func performGuestLogin() async {
        do {
            try await viewModel.loginAsGuest()
            accessToken = AuthSessionStore.accessToken ?? ""
            userId = UserDefaults.standard.string(forKey: "userId") ?? ""
            userSeed = UserDefaults.standard.integer(forKey: "userSeed")
            withAnimation { isLoggedIn = true }
        } catch {
            print("🚨 [게스트 로그인 실패] \(error.localizedDescription)")
        }
    }

    // MARK: - (보존용) 진짜 애플 로그인 결과 처리 로직
    private func handleAppleLoginResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user
                print("User ID: \(userIdentifier)")
                
                withAnimation {
                    self.isLoggedIn = true
                }
            }
        case .failure(let error):
            print("애플 로그인 실패: \(error.localizedDescription)")
        }
    }
}

// MARK: - 밀도 높은 우주 배경 컴포넌트
private struct DenseStarFieldView: View {
    let isAnimating: Bool
    
    private let stars: [CGPoint] = (0..<150).map { _ in
        CGPoint(x: CGFloat.random(in: 0...1), y: CGFloat.random(in: 0...1))
    }
    
    private let lines: [(CGPoint, CGPoint)] = (0..<30).map { _ in
        let start = CGPoint(x: CGFloat.random(in: 0...1), y: CGFloat.random(in: 0...1))
        let end = CGPoint(
            x: start.x + CGFloat.random(in: -0.15...0.15),
            y: start.y + CGFloat.random(in: -0.15...0.15)
        )
        return (start, end)
    }
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            ZStack {
                Path { path in
                    for line in lines {
                        path.move(to: CGPoint(x: line.0.x * size.width, y: line.0.y * size.height))
                        path.addLine(to: CGPoint(x: line.1.x * size.width, y: line.1.y * size.height))
                    }
                }
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                
                ForEach(0..<stars.count, id: \.self) { index in
                    let star = stars[index]
                    let starSize = CGFloat.random(in: 1...3.5)
                    let isTwinkling = index % 3 == 0
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: starSize, height: starSize)
                        .position(x: star.x * size.width, y: star.y * size.height)
                        .opacity(isTwinkling ? (isAnimating ? 1.0 : 0.2) : CGFloat.random(in: 0.3...0.8))
                        .blur(radius: starSize > 2.5 ? 1 : 0)
                        .animation(
                            isTwinkling ? .easeInOut(duration: Double.random(in: 1.5...3.0)).repeatForever(autoreverses: true) : .default,
                            value: isAnimating
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    LoginView()
}
