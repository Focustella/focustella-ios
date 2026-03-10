import UIKit
import Combine

final class AppAccessibility: ObservableObject {
    static let shared = AppAccessibility()

    @Published private(set) var isReduceMotionEnabled: Bool = UIAccessibility.isReduceMotionEnabled

    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default
            .publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)
    }
}
