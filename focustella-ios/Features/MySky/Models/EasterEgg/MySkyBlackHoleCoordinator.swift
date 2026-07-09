import SwiftUI
import Combine

@MainActor
final class MySkyBlackHoleCoordinator: ObservableObject {
    enum Phase: Int, Equatable {
        case idle
        case stage4
        case stage5
        case stage6
        case stage7Spawning
        case stage7Absorbing
        case stage7AwaitingInput
        case stage8Collapsing
        case blackout
        case whiteFlash
        case cooldown
    }

    struct TimelineDurations: Equatable {
        var stage7Spawning: TimeInterval
        var stage7Absorbing: TimeInterval
        var stage8Collapsing: TimeInterval
        var blackout: TimeInterval
        var whiteFlash: TimeInterval

        static let standard = TimelineDurations(
            stage7Spawning: 0.45,
            stage7Absorbing: 1.8,
            stage8Collapsing: 0.7,
            blackout: 1.05,
            whiteFlash: 0.15
        )

        static let reducedMotion = TimelineDurations(
            stage7Spawning: 0.28,
            stage7Absorbing: 1.1,
            stage8Collapsing: 0.45,
            blackout: 0.55,
            whiteFlash: 0.12
        )
    }

    struct OverlayParameters: Equatable {
        var center: CGPoint = CGPoint(x: 0.5, y: 0.54)
        var radius: CGFloat = 0.18
        var opacity: CGFloat = 0
        var swirlStrength: CGFloat = 0
        var distortion: CGFloat = 0
        var flashProgress: CGFloat = 0
    }

    struct AbsorptionParameters: Equatable {
        var vignette: CGFloat = 0
        var lensJitter: CGFloat = 0
        var inwardPull: CGFloat = 0
        var swirl: CGFloat = 0
        var collapse: CGFloat = 0
        var edgeFade: CGFloat = 0
        var centerDarkening: CGFloat = 0
        var blackout: CGFloat = 0
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var overlay = OverlayParameters()
    @Published private(set) var absorption = AbsorptionParameters()
    @Published private(set) var stressScore: CGFloat = 0
    @Published private(set) var whiteFlashOpacity: CGFloat = 0
    @Published private(set) var lastCooldownDuration: TimeInterval = 0

    var isInputLocked: Bool {
        switch phase {
        case .stage7Spawning, .stage7Absorbing, .stage7AwaitingInput, .stage8Collapsing, .blackout, .whiteFlash:
            return true
        default:
            return false
        }
    }

    var isAwaitingUserInputToReturn: Bool {
        phase == .stage7AwaitingInput
    }

    var showsSingularityOverlay: Bool {
        switch phase {
        case .stage7Spawning, .stage7Absorbing, .stage7AwaitingInput, .stage8Collapsing, .blackout, .whiteFlash:
            return true
        default:
            return false
        }
    }

    var showsAbsorptionCanvas: Bool {
        switch phase {
        case .stage4, .stage5, .stage6, .stage7Spawning, .stage7Absorbing, .stage7AwaitingInput, .stage8Collapsing, .blackout:
            return true
        default:
            return false
        }
    }

    private let standardTimeline: TimelineDurations
    private let reducedMotionTimeline: TimelineDurations
    private let cooldownRange: ClosedRange<TimeInterval>
    private let sleep: @Sendable (TimeInterval) async -> Void
    private let cooldownSampler: @Sendable (ClosedRange<TimeInterval>) -> TimeInterval

    private var sequenceTask: Task<Void, Never>?
    private var currentProtectionStage: Int = 0
    private var isFeatureEnabled = true

    init(
        standardTimeline: TimelineDurations = TimelineDurations(
            stage7Spawning: 0.45,
            stage7Absorbing: 1.8,
            stage8Collapsing: 0.7,
            blackout: 1.05,
            whiteFlash: 0.15
        ),
        reducedMotionTimeline: TimelineDurations = TimelineDurations(
            stage7Spawning: 0.28,
            stage7Absorbing: 1.1,
            stage8Collapsing: 0.45,
            blackout: 0.55,
            whiteFlash: 0.12
        ),
        cooldownRange: ClosedRange<TimeInterval> = 10...20,
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
            guard seconds > 0 else { return }
            try? await Task.sleep(for: .seconds(seconds))
        },
        cooldownSampler: @escaping @Sendable (ClosedRange<TimeInterval>) -> TimeInterval = { range in
            Double.random(in: range)
        }
    ) {
        self.standardTimeline = standardTimeline
        self.reducedMotionTimeline = reducedMotionTimeline
        self.cooldownRange = cooldownRange
        self.sleep = sleep
        self.cooldownSampler = cooldownSampler
    }

    func setFeatureEnabled(_ enabled: Bool) {
        guard isFeatureEnabled != enabled else { return }
        isFeatureEnabled = enabled
        if !enabled {
            cancelTimeline()
            resetVisualStateToIdle()
            phase = .idle
            currentProtectionStage = 0
            stressScore = 0
        }
    }

    func updateStress(score: CGFloat) {
        let clampedScore = max(0, min(1, score))
        let isPreSingularityStage = [4, 5, 6].contains(currentProtectionStage)
            && (phase == .stage4 || phase == .stage5 || phase == .stage6)

        guard isPreSingularityStage else {
            if stressScore != 0 {
                stressScore = 0
            }
            return
        }

        guard abs(clampedScore - stressScore) >= 0.02 else { return }
        stressScore = clampedScore
        applyPreSingularityStage(currentProtectionStage)
    }

    func registerProtectionActivation(
        activationCount: Int,
        reduceMotion: Bool,
        preSpawnDelay: TimeInterval = 0
    ) {
        guard isFeatureEnabled else { return }
        guard phase != .cooldown else { return }
        guard phase != .stage7Spawning,
              phase != .stage7Absorbing,
              phase != .stage7AwaitingInput,
              phase != .stage8Collapsing,
              phase != .blackout,
              phase != .whiteFlash else {
            return
        }

        switch activationCount {
        case 4:
            cancelTimeline()
            currentProtectionStage = 4
            applyPreSingularityStage(4)
        case 5:
            cancelTimeline()
            currentProtectionStage = 5
            applyPreSingularityStage(5)
        case 6:
            cancelTimeline()
            currentProtectionStage = 6
            applyPreSingularityStage(6)
        case let value where value >= 7:
            currentProtectionStage = 7
            startAutomaticSequence(
                reduceMotion: reduceMotion,
                preSpawnDelay: max(0, preSpawnDelay)
            )
        default:
            break
        }
    }

    func resetAfterCooldown() {
        cancelTimeline()
        resetVisualStateToIdle()
        phase = .idle
        currentProtectionStage = 0
        stressScore = 0
    }

    func beginReturnToSky(reduceMotion: Bool) {
        guard phase == .stage7AwaitingInput else { return }
        startReturnSequence(reduceMotion: reduceMotion)
    }

    private func applyPreSingularityStage(_ stage: Int) {
        let stress = 0.45 + stressScore * 0.55

        switch stage {
        case 4:
            phase = .stage4
            overlay.opacity = 0
            overlay.radius = 0.17
            overlay.swirlStrength = 0
            overlay.distortion = 0
            overlay.flashProgress = 0

            absorption.vignette = 0.16 + 0.20 * stress
            absorption.lensJitter = 0.006 + 0.004 * stress
            absorption.inwardPull = 0.0
            absorption.swirl = 0
            absorption.collapse = 0
            absorption.edgeFade = 0.04
            absorption.centerDarkening = 0
            absorption.blackout = 0

        case 5:
            phase = .stage5
            overlay.opacity = 0
            overlay.radius = 0.18
            overlay.swirlStrength = 0
            overlay.distortion = 0
            overlay.flashProgress = 0

            absorption.vignette = 0.24 + 0.20 * stress
            absorption.lensJitter = 0.012 + 0.012 * stress
            absorption.inwardPull = 0.028 + 0.028 * stress
            absorption.swirl = 0
            absorption.collapse = 0.04
            absorption.edgeFade = 0.10
            absorption.centerDarkening = 0.06
            absorption.blackout = 0

        case 6:
            phase = .stage6
            overlay.opacity = 0
            overlay.radius = 0.20
            overlay.swirlStrength = 0
            overlay.distortion = 0
            overlay.flashProgress = 0

            absorption.vignette = 0.34 + 0.20 * stress
            absorption.lensJitter = 0.016 + 0.016 * stress
            absorption.inwardPull = 0.085 + 0.06 * stress
            absorption.swirl = 0.10 + 0.12 * stress
            absorption.collapse = 0.18 + 0.20 * stress
            absorption.edgeFade = 0.30 + 0.20 * stress
            absorption.centerDarkening = 0.35 + 0.25 * stress
            absorption.blackout = 0

        default:
            break
        }

        whiteFlashOpacity = 0
    }

    private func startAutomaticSequence(reduceMotion: Bool, preSpawnDelay: TimeInterval) {
        cancelTimeline()

        let timeline = reduceMotion ? reducedMotionTimeline : standardTimeline
        sequenceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.sequenceTask = nil }

            if preSpawnDelay > 0 {
                await self.sleep(preSpawnDelay)
                guard !Task.isCancelled else { return }
            }

            self.phase = .stage7Spawning
            self.overlay.flashProgress = 0
            self.whiteFlashOpacity = 0

            await self.animate(duration: timeline.stage7Spawning) { [self] progress in
                let t = self.smoothstep(progress)
                self.overlay.opacity = self.clamp(0.05 + 0.60 * t)
                self.overlay.radius = self.clamp(0.09 + 0.20 * t)
                self.overlay.swirlStrength = reduceMotion ? 0.18 : self.clamp(0.25 + 0.60 * t)
                self.overlay.distortion = self.clamp(0.30 + 0.38 * t)

                self.absorption.vignette = self.clamp(0.42 + 0.16 * t)
                self.absorption.lensJitter = reduceMotion ? 0.004 : self.clamp(0.018 + 0.012 * t)
                self.absorption.inwardPull = self.clamp(0.16 + 0.28 * t)
                self.absorption.swirl = reduceMotion ? 0 : self.clamp(0.20 + 0.36 * t)
                self.absorption.collapse = self.clamp(0.18 + 0.26 * t)
                self.absorption.edgeFade = self.clamp(0.35 + 0.25 * t)
                self.absorption.centerDarkening = self.clamp(0.34 + 0.30 * t)
                self.absorption.blackout = 0
            }

            guard !Task.isCancelled else { return }

            self.phase = .stage7Absorbing
            await self.animate(duration: timeline.stage7Absorbing) { [self] progress in
                let t = self.smoothstep(progress)
                self.overlay.opacity = self.clamp(0.65 + 0.22 * t)
                self.overlay.radius = self.clamp(0.28 + 0.12 * t)
                self.overlay.swirlStrength = reduceMotion ? 0.20 : self.clamp(0.82 + 0.24 * t)
                self.overlay.distortion = self.clamp(0.70 + 0.14 * t)

                self.absorption.vignette = self.clamp(0.58 + 0.22 * t)
                self.absorption.lensJitter = reduceMotion ? 0.003 : self.clamp(0.032 - 0.015 * t)
                self.absorption.inwardPull = self.clamp(0.45 + 0.60 * t)
                self.absorption.swirl = reduceMotion ? 0 : self.clamp(0.62 + 0.34 * t)
                self.absorption.collapse = self.clamp(0.45 + 0.48 * t)
                self.absorption.edgeFade = self.clamp(0.62 + 0.32 * t)
                self.absorption.centerDarkening = self.clamp(0.64 + 0.30 * t)
                self.absorption.blackout = self.clamp(0.02 + 0.06 * t)
            }

            guard !Task.isCancelled else { return }
            self.phase = .stage7AwaitingInput
            self.overlay.opacity = 0.84
            self.overlay.radius = 0.38
            self.overlay.swirlStrength = reduceMotion ? 0.18 : 0.95
            self.overlay.distortion = 0.80
            self.absorption.vignette = 0.80
            self.absorption.lensJitter = reduceMotion ? 0.001 : 0.010
            self.absorption.inwardPull = 1.0
            self.absorption.swirl = reduceMotion ? 0 : 0.92
            self.absorption.collapse = 0.90
            self.absorption.edgeFade = 0.90
            self.absorption.centerDarkening = 0.95
            self.absorption.blackout = 0.08
        }
    }

    private func startReturnSequence(reduceMotion: Bool) {
        cancelTimeline()

        let timeline = reduceMotion ? reducedMotionTimeline : standardTimeline
        sequenceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.sequenceTask = nil }

            self.phase = .stage8Collapsing
            await self.animate(duration: timeline.stage8Collapsing) { [self] progress in
                let t = self.smoothstep(progress)
                self.overlay.opacity = self.clamp(0.88 - (0.30 * t))
                self.overlay.radius = self.clamp(0.38 - (0.26 * t))
                self.overlay.swirlStrength = reduceMotion ? 0.12 : self.clamp(0.92 + (0.18 * t))
                self.overlay.distortion = self.clamp(0.80 + (0.12 * t))
                self.overlay.flashProgress = 0

                self.absorption.vignette = self.clamp(0.80 + (0.18 * t))
                self.absorption.lensJitter = reduceMotion ? 0.001 : self.clamp(0.010 + (0.008 * t))
                self.absorption.inwardPull = 1.0
                self.absorption.swirl = reduceMotion ? 0 : self.clamp(0.92 + (0.08 * t))
                self.absorption.collapse = self.clamp(0.90 + (0.10 * t))
                self.absorption.edgeFade = self.clamp(0.90 + (0.10 * t))
                self.absorption.centerDarkening = 1.0
                self.absorption.blackout = self.clamp(0.10 + (0.58 * t))
            }

            guard !Task.isCancelled else { return }

            self.phase = .blackout
            await self.animate(duration: timeline.blackout) { [self] progress in
                let t = self.smoothstep(progress)
                self.overlay.opacity = self.clamp(0.58 * (1 - t))
                self.overlay.radius = self.clamp(0.12 - (0.06 * t))
                self.overlay.swirlStrength = reduceMotion ? 0 : self.clamp(0.36 * (1 - t))
                self.overlay.distortion = self.clamp(0.24 * (1 - t))
                self.overlay.flashProgress = 0

                self.absorption.vignette = self.clamp(0.60 * (1 - t))
                self.absorption.lensJitter = self.clamp(0.003 * (1 - t))
                self.absorption.inwardPull = self.clamp(0.45 * (1 - t))
                self.absorption.swirl = reduceMotion ? 0 : self.clamp(0.40 * (1 - t))
                self.absorption.collapse = self.clamp(0.70 * (1 - t))
                self.absorption.edgeFade = self.clamp(0.82 * (1 - t))
                self.absorption.centerDarkening = self.clamp(0.90 * (1 - t))
                self.absorption.blackout = self.clamp(0.82 + (0.18 * t))
                self.whiteFlashOpacity = 0
            }

            guard !Task.isCancelled else { return }

            self.lastCooldownDuration = 0
            self.resetVisualStateToIdle()
            self.phase = .idle
            self.currentProtectionStage = 0
            self.stressScore = 0
        }
    }

    private func cancelTimeline() {
        sequenceTask?.cancel()
        sequenceTask = nil
    }

    private func resetVisualStateToIdle() {
        overlay.opacity = 0
        overlay.radius = 0.18
        overlay.swirlStrength = 0
        overlay.distortion = 0
        overlay.flashProgress = 0

        absorption.vignette = 0
        absorption.lensJitter = 0
        absorption.inwardPull = 0
        absorption.swirl = 0
        absorption.collapse = 0
        absorption.edgeFade = 0
        absorption.centerDarkening = 0
        absorption.blackout = 0

        whiteFlashOpacity = 0
    }

    private func animate(duration: TimeInterval, update: @escaping (CGFloat) -> Void) async {
        guard duration > 0 else {
            update(1)
            return
        }

        let steps = max(1, Int(duration * 32))
        for step in 0...steps {
            guard !Task.isCancelled else { return }
            let progress = CGFloat(step) / CGFloat(steps)
            update(progress)
            if step < steps {
                await sleep(duration / Double(steps))
            }
        }
    }

    private func smoothstep(_ t: CGFloat) -> CGFloat {
        let clamped = clamp(t)
        return clamped * clamped * (3 - (2 * clamped))
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
