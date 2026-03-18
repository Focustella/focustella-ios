// 📂 Features/MySky/Components/TutorialOverlayView.swift
import SwiftUI

enum TutorialStep: Int {
    case notStarted = 0
    case welcome = 1           // "이곳이 나의 밤하늘이에요!"
    case pointToStart = 2      // "밤하늘에 나만의 별자리를 새겨볼까요?"
    case suggest5Min = 3       // "우리 5분만 집중해볼까요?"
    case warping = 4           // 타이머 진행 중 (입력 방지)
    case constellationDone = 5 // "별자리가 만들어졌어요!"
    case spawningReward = 6    // 보상 별 떨어지는 중 (입력 대기)
    case dailyReward = 7       // "튜토리얼을 완료해서 별 한개를 받았어요."
    case finalGreeting = 8     // "이제 나의 밤하늘을 가득 채우러 가볼까요?"
    case done = 9              // 완전 종료
}

struct TutorialOverlayView: View {
    @Binding var step: TutorialStep
    var onStartSession: () -> Void
    var onTriggerReward: () -> Void // 🔥 별자리 생성 연출용 콜백 추가
    var onFinish: () -> Void
    
    var body: some View {
        ZStack {
            // 🔥 배경 밝기 조절 (0.3)
            // 보상 연출 중(.spawningReward ~ .finalGreeting)에도 하늘이 잘 보이게 투명도 0 유지
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .opacity((step == .warping || step == .constellationDone || step == .spawningReward || step == .dailyReward || step == .finalGreeting) ? 0.0 : 1.0)
            
            VStack {
                if step == .welcome {
                    tutorialTooltip(text: "이곳이 나의 밤하늘이에요! 🌌\n아직은 텅 비어있네요.")
                        .padding(.top, 120)
                }
                
                Spacer()
                
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
            withAnimation(.spring()) {
                if step == .welcome { step = .pointToStart }
                else if step == .pointToStart { step = .suggest5Min }
                else if step == .constellationDone {
                    step = .spawningReward // 터치하면 별자리 생성 연출 시작
                    onTriggerReward()
                }
                else if step == .dailyReward { step = .finalGreeting }
                else if step == .finalGreeting {
                    step = .done
                    onFinish() // 최종 종료! 카메라 원래대로
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
