import SwiftUI
import Combine

@MainActor
final class MySkyInputProtectionCoordinator: ObservableObject {
    private static let defaultMessage = "입력이 너무 빨라 잠시 쉬는 중이에요."

    @Published private(set) var isActive = false
    @Published private(set) var isBannerVisible = false
    @Published private(set) var activationCount = 0
    @Published private(set) var bannerMessage = defaultMessage

    private var releaseTask: Task<Void, Never>?

    @discardableResult
    func activate(duration: TimeInterval = 3.0, onActivate: () -> Void) -> Bool {
        releaseTask?.cancel()
        let didEnterNewActivation = !isActive

        if didEnterNewActivation {
            onActivate()
            activationCount += 1
        }

        bannerMessage = warningMessage(for: activationCount)
        isActive = true
        withAnimation(.easeInOut(duration: 0.18)) {
            isBannerVisible = true
        }

        scheduleBannerRelease(duration: duration, unlockInput: true)

        return didEnterNewActivation
    }

    func warningMessage(for activationCount: Int) -> String {
        switch activationCount {
        case 3:
            return "천천히요, 시공간이 흔들립니다"
        case 4:
            return "시공간 안정화 중…"
        case 5:
            return "중력장이 요동칩니다"
        case 6:
            return "중력이 강해지는 게 느껴지나요?"
        case 7:
            return "작별 인사를 할 시간이군요"
        case 8:
            return "작별 인사를 할 시간이군요"
        default:
            return Self.defaultMessage
        }
    }

    func showTransientWarning(_ message: String, duration: TimeInterval = 1.35) {
        guard !isActive else { return }
        releaseTask?.cancel()
        bannerMessage = message
        withAnimation(.easeInOut(duration: 0.18)) {
            isBannerVisible = true
        }
        scheduleBannerRelease(duration: duration, unlockInput: false)
    }

    func resetActivationProgress() {
        activationCount = 0
        bannerMessage = Self.defaultMessage
    }

    func setActivationCountForDebug(_ count: Int, showBanner: Bool = true) {
        activationCount = max(0, count)
        bannerMessage = warningMessage(for: activationCount)

        guard showBanner else { return }
        releaseTask?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) {
            isBannerVisible = true
        }
        scheduleBannerRelease(duration: 1.2, unlockInput: false)
    }

    func reset() {
        releaseTask?.cancel()
        releaseTask = nil
        isActive = false
        isBannerVisible = false
        bannerMessage = warningMessage(for: activationCount)
    }

    private func scheduleBannerRelease(duration: TimeInterval, unlockInput: Bool) {
        releaseTask?.cancel()
        releaseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                self.isBannerVisible = false
            }
            if unlockInput {
                self.isActive = false
            }
        }
    }
}
