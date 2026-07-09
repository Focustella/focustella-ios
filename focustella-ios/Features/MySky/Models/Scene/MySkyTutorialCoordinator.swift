import CoreGraphics
import SwiftUI

struct MySkyTutorialCoordinator {
    let goldenStarSkyPoint = CGPoint(x: 0.5, y: 0.5)

    func initialStep(hasSeenTutorial: Bool) -> TutorialStep {
        hasSeenTutorial ? .done : .askNickname
    }

    func initialCamera(hasSeenTutorial: Bool) -> MySkyCameraState {
        hasSeenTutorial ? .default : MySkyCameraState(centerSky: goldenStarSkyPoint, zoom: 1.0)
    }

    func shouldRollbackDailySheetDismissal(
        isShowing: Bool,
        hasSeenTutorial: Bool,
        step: TutorialStep
    ) -> Bool {
        !isShowing && !hasSeenTutorial && step == .waitDaily
    }

    func stepAfterDailySessionCompleted(
        hasSeenTutorial: Bool,
        step: TutorialStep
    ) -> TutorialStep? {
        !hasSeenTutorial && step == .waitDaily ? .spawningReward : nil
    }

    func applyDailyRewardImpact(step: Binding<TutorialStep>) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            step.wrappedValue = .dailyReward
        }
    }
}
