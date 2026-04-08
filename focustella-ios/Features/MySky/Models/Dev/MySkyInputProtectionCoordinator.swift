import SwiftUI
import Combine

@MainActor
final class MySkyInputProtectionCoordinator: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isBannerVisible = false
    @Published private(set) var activationCount = 0

    private var releaseTask: Task<Void, Never>?

    @discardableResult
    func activate(duration: TimeInterval = 3.0, onActivate: () -> Void) -> Bool {
        releaseTask?.cancel()
        let didEnterNewActivation = !isActive

        if didEnterNewActivation {
            onActivate()
            activationCount += 1
        }

        isActive = true
        withAnimation(.easeInOut(duration: 0.18)) {
            isBannerVisible = true
        }

        releaseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                self.isBannerVisible = false
            }
            self.isActive = false
        }

        return didEnterNewActivation
    }

    func reset() {
        releaseTask?.cancel()
        releaseTask = nil
        isActive = false
        isBannerVisible = false
    }
}
