import Foundation

enum FocusSessionPresentationPhase: Equatable {
    case idle
    case movingToTarget(orderIndex: Int)
    case waitingToBirth(orderIndex: Int)
    case birthing(orderIndex: Int, token: Int)
    case overviewing
    case awaitingMemo
}

struct FocusSessionPresentationState: Equatable {
    var constellationId: UUID?
    var discoveryOrder: [Int]
    var actualDiscoveredCount: Int
    var renderedDiscoveredCount: Int
    var currentTargetOrderIndex: Int?
    var activeBirthStarId: UUID?
    var phase: FocusSessionPresentationPhase
    var clock: FocusSessionClock

    static let idle = FocusSessionPresentationState(
        constellationId: nil,
        discoveryOrder: [],
        actualDiscoveredCount: 0,
        renderedDiscoveredCount: 0,
        currentTargetOrderIndex: nil,
        activeBirthStarId: nil,
        phase: .idle,
        clock: .live
    )

    var hasActiveSession: Bool {
        constellationId != nil && phase != .idle
    }

    var isAwaitingBirth: Bool {
        if case .waitingToBirth = phase { return true }
        return false
    }

    var isMovingCamera: Bool {
        if case .movingToTarget = phase { return true }
        if case .overviewing = phase { return true }
        return false
    }

    var isBirthing: Bool {
        if case .birthing = phase { return true }
        return false
    }

    var isTutorialClock: Bool {
        if case .tutorial = clock { return true }
        return false
    }

    var nextOrderIndexToRender: Int? {
        guard renderedDiscoveredCount < discoveryOrder.count else { return nil }
        return renderedDiscoveredCount
    }

    var canBeginBirth: Bool {
        guard case let .waitingToBirth(orderIndex) = phase else { return false }
        return actualDiscoveredCount > renderedDiscoveredCount && renderedDiscoveredCount == orderIndex
    }

    var isComplete: Bool {
        renderedDiscoveredCount >= discoveryOrder.count
    }

    mutating func reset() {
        self = .idle
    }
}
