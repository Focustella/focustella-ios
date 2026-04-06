import Foundation

enum FocusSessionClock: Equatable {
    case live
    case tutorial(stepSeconds: TimeInterval = 6, pollInterval: TimeInterval = 0.12)

    var tutorialStepSeconds: TimeInterval? {
        switch self {
        case .live:
            return nil
        case let .tutorial(stepSeconds, _):
            return stepSeconds
        }
    }

    var pollInterval: TimeInterval {
        switch self {
        case .live:
            return 1.0
        case let .tutorial(_, pollInterval):
            return pollInterval
        }
    }
}
