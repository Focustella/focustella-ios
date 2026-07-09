import Combine
import XCTest
@testable import focustella_ios

@MainActor
final class MySkyBlackHoleCoordinatorTests: XCTestCase {
    func testInputProtectionWarningMessageMapping() {
        let coordinator = MySkyInputProtectionCoordinator()

        XCTAssertEqual(coordinator.warningMessage(for: 1), "입력이 너무 빨라 잠시 쉬는 중이에요.")
        XCTAssertEqual(coordinator.warningMessage(for: 2), "입력이 너무 빨라 잠시 쉬는 중이에요.")
        XCTAssertEqual(coordinator.warningMessage(for: 3), "천천히요, 시공간이 흔들립니다")
        XCTAssertEqual(coordinator.warningMessage(for: 4), "시공간 안정화 중…")
        XCTAssertEqual(coordinator.warningMessage(for: 5), "중력장이 요동칩니다")
        XCTAssertEqual(coordinator.warningMessage(for: 6), "중력이 강해지는 게 느껴지나요?")
        XCTAssertEqual(coordinator.warningMessage(for: 7), "작별 인사를 할 시간이군요")
        XCTAssertEqual(coordinator.warningMessage(for: 8), "작별 인사를 할 시간이군요")
    }

    func testResetActivationProgressClearsCounter() {
        let coordinator = MySkyInputProtectionCoordinator()

        let didActivate = coordinator.activate(duration: 0.01) {}

        XCTAssertTrue(didActivate)
        XCTAssertEqual(coordinator.activationCount, 1)

        coordinator.resetActivationProgress()

        XCTAssertEqual(coordinator.activationCount, 0)
        XCTAssertEqual(coordinator.bannerMessage, coordinator.warningMessage(for: 0))
    }

    func testProtectionCountTransitionsToPreSingularityStages() {
        let coordinator = makeCoordinator()

        coordinator.registerProtectionActivation(activationCount: 4, reduceMotion: false)
        XCTAssertEqual(coordinator.phase, .stage4)

        coordinator.registerProtectionActivation(activationCount: 5, reduceMotion: false)
        XCTAssertEqual(coordinator.phase, .stage5)

        coordinator.registerProtectionActivation(activationCount: 6, reduceMotion: false)
        XCTAssertEqual(coordinator.phase, .stage6)
    }

    func testStageSevenWaitsForUserInputThenReturnsImmediatelyToIdle() async {
        let coordinator = makeCoordinator(
            cooldownRange: 0.01...0.02,
            cooldownSampler: { _ in 0.018 }
        )

        var observed: [MySkyBlackHoleCoordinator.Phase] = []
        let cancellable = coordinator.$phase.sink { observed.append($0) }
        defer { cancellable.cancel() }

        coordinator.registerProtectionActivation(activationCount: 7, reduceMotion: false)

        for _ in 0..<400 {
            if coordinator.phase == .stage7AwaitingInput {
                break
            }
            await Task.yield()
        }

        XCTAssertEqual(coordinator.phase, .stage7AwaitingInput)
        XCTAssertEqual(coordinator.lastCooldownDuration, 0)

        for _ in 0..<100 {
            await Task.yield()
        }
        XCTAssertEqual(coordinator.phase, .stage7AwaitingInput)

        coordinator.beginReturnToSky(reduceMotion: false)

        for _ in 0..<800 {
            if coordinator.phase == .idle {
                break
            }
            await Task.yield()
        }

        XCTAssertEqual(coordinator.phase, .idle)
        XCTAssertEqual(coordinator.lastCooldownDuration, 0)

        let expectedOrder: [MySkyBlackHoleCoordinator.Phase] = [
            .idle,
            .stage7Spawning,
            .stage7Absorbing,
            .stage7AwaitingInput,
            .stage8Collapsing,
            .blackout,
            .idle
        ]

        XCTAssertTrue(containsOrderedSubsequence(expectedOrder, in: observed), "Observed order: \(observed)")
    }

    private func makeCoordinator(
        cooldownRange: ClosedRange<TimeInterval> = 0.01...0.02,
        cooldownSampler: @escaping @Sendable (ClosedRange<TimeInterval>) -> TimeInterval = { $0.lowerBound }
    ) -> MySkyBlackHoleCoordinator {
        let timeline = MySkyBlackHoleCoordinator.TimelineDurations(
            stage7Spawning: 0.01,
            stage7Absorbing: 0.01,
            stage8Collapsing: 0.01,
            blackout: 0.01,
            whiteFlash: 0.01
        )
        return MySkyBlackHoleCoordinator(
            standardTimeline: timeline,
            reducedMotionTimeline: timeline,
            cooldownRange: cooldownRange,
            sleep: { _ in
                await Task.yield()
            },
            cooldownSampler: cooldownSampler
        )
    }

    private func containsOrderedSubsequence<T: Equatable>(_ expected: [T], in observed: [T]) -> Bool {
        guard !expected.isEmpty else { return true }
        var index = 0

        for item in observed {
            if item == expected[index] {
                index += 1
                if index == expected.count {
                    return true
                }
            }
        }

        return false
    }
}
