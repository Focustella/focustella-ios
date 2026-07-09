import Combine
import CoreGraphics
import Foundation
import UIKit
import SwiftUI

@MainActor
final class MySkyEffectsCoordinator: ObservableObject {
    @Published private(set) var showDailyRewardText = false
    @Published private(set) var dailyStarRippleCenter: CGPoint?
    @Published private(set) var dailyRewardEffectToken = 0

    private var rewardSequenceTask: Task<Void, Never>?
    private var dailyRewardTextTask: Task<Void, Never>?

    func cancelDailyRewardEffects() {
        rewardSequenceTask?.cancel()
        dailyRewardTextTask?.cancel()
        rewardSequenceTask = nil
        dailyRewardTextTask = nil
        dailyStarRippleCenter = nil
        showDailyRewardText = false
    }

    func runDailyRewardSequence(
        point: CGPoint,
        targetCamera: MySkyCameraState,
        cleanupDelay: TimeInterval,
        animateCamera: @escaping @MainActor (MySkyCameraState, TimeInterval) -> Void,
        appendReward: @escaping @MainActor (CGPoint) -> Void,
        clearSelection: @escaping @MainActor () -> Void,
        onImpact: @escaping @MainActor () -> Void,
        onCleanup: @escaping @MainActor () -> Void
    ) {
        rewardSequenceTask?.cancel()
        animateCamera(targetCamera, 1.0)

        rewardSequenceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }

            dailyRewardEffectToken += 1
            dailyStarRippleCenter = point
            appendReward(point)
            clearSelection()

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onImpact()

            try? await Task.sleep(for: .seconds(cleanupDelay))
            guard !Task.isCancelled else { return }

            dailyStarRippleCenter = nil
            onCleanup()
        }
    }

    func showDailyRewardTextTemporarily(duration: TimeInterval) {
        dailyRewardTextTask?.cancel()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showDailyRewardText = true
        }

        dailyRewardTextTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) {
                showDailyRewardText = false
            }
        }
    }
}
