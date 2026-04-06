// 📂 Features/MySky/Components/TutorialOverlayView.swift
import SwiftUI

enum TutorialStep: Int {
    case notStarted = 0
    case askNickname = 1
    case welcome = 2
    case pointToStart = 3
    case suggest5Min = 4
    case warping = 5
    case constellationDone = 6
    case suggestDaily = 7      // 🔥 추가: "오늘 하루를 계획해볼까요?"
    case waitDaily = 8         // 🔥 추가: 시트가 열려있는 동안 투명해지는 대기 상태
    case spawningReward = 9
    case dailyReward = 10
    case finalGreeting = 11
    case done = 12
}
struct TutorialOverlayView: View {
    @Binding var step: TutorialStep
    
    // 🔥 닉네임 입력을 위한 상태 변수
    @State private var nicknameInput: String = ""
    @State private var isSaving: Bool = false
    
    var onSaveNickname: (String) async -> Bool // 백엔드 통신용 콜백
    var onStartSession: () -> Void
    var onOpenDailySession: () -> Void // 🔥 추가: 일일 세션 바텀시트 열기 콜백
    var onTriggerReward: () -> Void
    var onFinish: () -> Void
    
    var body: some View {
        ZStack {
            // 배경 밝기 조절
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .opacity((step == .warping || step == .constellationDone || step == .spawningReward || step == .dailyReward || step == .finalGreeting) ? 0.0 : 1.0)
            
            VStack {
                // 🔥 1. 닉네임 입력 단계
                if step == .askNickname {
                    VStack(spacing: 24) {
                        tutorialTooltip(text: "반가워요! 👋\n어떻게 부르면 좋을까요?")
                        
                        TextField("닉네임 입력", text: $nicknameInput)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 40)
                            .disabled(isSaving)
                        
                        Button(action: {
                            Task {
                                isSaving = true
                                // 백엔드 저장 시도
                                let success = await onSaveNickname(nicknameInput)
                                isSaving = false
                                
                                if success {
                                    // 성공하면 다음 튜토리얼로 자연스럽게 이동!
                                    withAnimation(.spring()) {
                                        step = .welcome
                                    }
                                }
                            }
                        }) {
                            if isSaving {
                                ProgressView().tint(.white)
                                    .frame(width: 200, height: 50)
                            } else {
                                Text("이름 정하기")
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                    .frame(width: 200, height: 50)
                                    .background(nicknameInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.white, in: Capsule())
                            }
                        }
                        .disabled(nicknameInput.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    }
                    .padding(.top, 120)
                }
                
                // 2. 환영 인사
                if step == .welcome {
                    tutorialTooltip(text: "이곳이 나의 밤하늘이에요! 🌌\n아직은 텅 비어있네요.")
                        .padding(.top, 120)
                }
                
                Spacer()
                
                // 3. 5분 집중 제안
                if step == .pointToStart || step == .suggest5Min {
                    VStack(spacing: 16) {
                        tutorialTooltip(text: step == .pointToStart ? "밤하늘에 나만의 별자리를\n새겨볼까요?" : "우리 5분만 집중해볼까요? ⏳")
                        
                        Image(systemName: "arrow.down")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                            .modifier(BounceAnimation())
                            .padding(.bottom, 8)
                        
                        if step == .suggest5Min {
                            Button {
                                withAnimation { step = .warping }
                                onStartSession()
                            } label: {
                                Text("5분 집중 시작하기")
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                    .frame(width: 220, height: 48)
                                    .background(Color.white, in: Capsule())
                            }
                        } else {
                            Color.clear.frame(width: 220, height: 48)
                        }
                    }
                    .padding(.bottom, 60)
                }
                
                if step == .constellationDone {
                    tutorialTooltip(text: "와아! 별자리가 만들어졌어요! ✨\n화면을 탭해보세요.")
                        .padding(.top, 120)
                }
                
                if step == .suggestDaily {
                                    VStack(spacing: 16) {
                                        tutorialTooltip(text: "집중을 멋지게 해내셨네요!\n이제 오늘 할 일을 계획하고\n황금 별을 받아볼까요? 🌟")
                                        
                                        Image(systemName: "arrow.down")
                                            .font(.largeTitle)
                                            .foregroundStyle(.yellow)
                                            .modifier(BounceAnimation())
                                            .padding(.bottom, 8)
                                        
                                        Button {
                                            withAnimation { step = .waitDaily } // 대기 상태로 변경
                                            onOpenDailySession() // 바텀시트 열기!
                                        } label: {
                                            Text("일일 세션 계획하기")
                                                .font(.headline)
                                                .foregroundStyle(.black)
                                                .frame(width: 220, height: 48)
                                                .background(Color.white, in: Capsule())
                                        }
                                    }
                                    .padding(.bottom, 60)
                                }
                
                if step == .dailyReward {
                    tutorialTooltip(text: "튜토리얼을 완료해서\n황금 별 한 개를 받았어요! 🌟")
                        .padding(.top, 120)
                }
                
                if step == .finalGreeting {
                    tutorialTooltip(text: "이제 나의 밤하늘을\n가득 채우러 가볼까요? 🚀")
                        .padding(.top, 120)
                }
            }
        }
        .onTapGesture {
            // 🔥 닉네임 입력 중(.askNickname)일 때는 배경을 터치해도 넘어가지 않도록 방어!
            guard step != .askNickname else { return }
            
            withAnimation(.spring()) {
                if step == .welcome { step = .pointToStart }
                else if step == .pointToStart { step = .suggest5Min }
                else if step == .constellationDone { step = .suggestDaily } // 🔥 별자리 완성 후 제안으로 넘어감
                else if step == .dailyReward { step = .finalGreeting }
                else if step == .finalGreeting {
                    step = .done
                    onFinish()
                }
            }
        }
    }
    
    private func tutorialTooltip(text: String) -> some View {
        Text(text)
            .font(.title3.bold())
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .foregroundStyle(.white)
            .padding(24)
            .background(Color(white: 0.2).opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.3), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 10)
    }
}

private struct BounceAnimation: ViewModifier {
    @State private var isBouncing = false
    func body(content: Content) -> some View {
        content
            .offset(y: isBouncing ? 10 : -10)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) { isBouncing = true }
            }
    }
}
