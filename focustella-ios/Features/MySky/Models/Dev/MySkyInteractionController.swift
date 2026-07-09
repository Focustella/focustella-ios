import SwiftUI
import QuartzCore
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class MySkyInteractionController {
    // Keep interaction updates at 60fps to avoid excessive SwiftUI invalidation on high-refresh devices.
    private let normalInputUpdateInterval: CFTimeInterval = 1.0 / 60.0
    private let pressureInputUpdateInterval: CFTimeInterval = 1.0 / 24.0
    private let stressVelocityStart: CGFloat = 1_000   // pt/s
    private let overloadTriggerDuration: CGFloat = 1.5 // seconds
    private let overloadDecayMultiplier: CGFloat = 1.2
    private let pressureRecoveryDelay: CFTimeInterval = 0.9
    private let pressureDetectionCooldown: CFTimeInterval = 3.0
    private var lastDragUpdateTime: CFTimeInterval = 0
    private var lastMagnifyUpdateTime: CFTimeInterval = 0
    private var lastRawDragSampleTime: CFTimeInterval = 0
    private var lastRawDragTranslation: CGSize = .zero
    private var overloadAccumulatedDuration: CGFloat = 0
    private var pressureRecoveryTask: Task<Void, Never>?
    private var isInputPressureMode: Bool = false
    private var pressureDetectionCooldownUntil: CFTimeInterval = 0

    struct Context {
        var cameraState: Binding<MySkyCameraState>
        var dragStartCamera: Binding<MySkyCameraState?>
        var magnifyStartZoom: Binding<CGFloat?>
        var selectedSession: Binding<FocusSession?>
        let dailyStars: [DailyStarItem]
        let selectedDailyStar: DailyStarItem?
        let onSelectDailyStar: (DailyStarItem?) -> Void

        let completionConstellationId: UUID?
        let liveConstellationId: UUID?
        let completedSessions: [FocusSession]
        let canvasSize: CGSize

        let coordinateMapper: (CGSize) -> MySkyCoordinateMapper
        let cameraController: (CGSize) -> MySkyCameraController
        let constellationById: (UUID) -> Constellation?
        let onInteractionBegan: () -> Void
        let onInteractionEnded: () -> Void
        let onInputPressureDetected: () -> Void
        let onInputStressChanged: (CGFloat) -> Void
    }

    func dragGesture(context: Context) -> some Gesture {
        DragGesture()
            .onChanged { value in
                context.onInteractionBegan()
                if context.dragStartCamera.wrappedValue == nil {
                    context.dragStartCamera.wrappedValue = context.cameraState.wrappedValue
                }

                let now = CACurrentMediaTime()
                self.registerDragPressureSample(
                    now: now,
                    translation: value.translation,
                    context: context
                )
                let updateInterval = self.isInputPressureMode ? self.pressureInputUpdateInterval : self.normalInputUpdateInterval
                guard now - self.lastDragUpdateTime >= updateInterval else { return }
                self.lastDragUpdateTime = now

                context.cameraState.wrappedValue = context.cameraController(context.canvasSize).dragging(
                    camera: context.dragStartCamera.wrappedValue ?? context.cameraState.wrappedValue,
                    translation: value.translation
                )
            }
            .onEnded { value in
                context.cameraState.wrappedValue = context.cameraController(context.canvasSize).dragging(
                    camera: context.dragStartCamera.wrappedValue ?? context.cameraState.wrappedValue,
                    translation: value.translation
                )
                context.dragStartCamera.wrappedValue = nil
                self.lastDragUpdateTime = 0
                self.resetDragPressureState()
                self.releaseInputPressureModeIfNeeded()
                context.onInputStressChanged(0)
                context.onInteractionEnded()
            }
    }

    func magnificationGesture(context: Context) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                context.onInteractionBegan()
                if context.magnifyStartZoom.wrappedValue == nil {
                    context.magnifyStartZoom.wrappedValue = context.cameraState.wrappedValue.zoom
                }

                let now = CACurrentMediaTime()
                let updateInterval = self.isInputPressureMode ? self.pressureInputUpdateInterval : self.normalInputUpdateInterval
                guard now - self.lastMagnifyUpdateTime >= updateInterval else { return }
                self.lastMagnifyUpdateTime = now

                context.cameraState.wrappedValue = MySkyCameraState(
                    centerSky: context.cameraState.wrappedValue.centerSky,
                    zoom: min(max((context.magnifyStartZoom.wrappedValue ?? context.cameraState.wrappedValue.zoom) * value, 0.22), 2.0)
                )
            }
            .onEnded { value in
                context.cameraState.wrappedValue = MySkyCameraState(
                    centerSky: context.cameraState.wrappedValue.centerSky,
                    zoom: min(max((context.magnifyStartZoom.wrappedValue ?? context.cameraState.wrappedValue.zoom) * value, 0.22), 2.0)
                )
                context.magnifyStartZoom.wrappedValue = nil
                self.lastMagnifyUpdateTime = 0
                self.releaseInputPressureModeIfNeeded()
                context.onInteractionEnded()
            }
    }

    func sessionTapGesture(size: CGSize, context: Context) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                self.selectSkyItem(
                    at: value.location,
                    size: size,
                    context: context
                )
            }
    }

    func prepareForNextProtectionActivation() {
        pressureDetectionCooldownUntil = 0
        lastDragUpdateTime = 0
        lastMagnifyUpdateTime = 0
        releaseInputPressureModeIfNeeded()
        resetDragPressureState()
    }

    private func selectSkyItem(
        at screenPoint: CGPoint,
        size: CGSize,
        context: Context
    ) {
        let mapper = context.coordinateMapper(size)
        let zoom = max(context.cameraState.wrappedValue.zoom, 0.22)
        // Keep tap precision tighter when zoomed out, and slightly more forgiving when zoomed in.
        let hitRadiusInScreen = max(10, min(24, 18 * zoom))

        if selectDailyRewardStar(
            at: screenPoint,
            mapper: mapper,
            hitRadiusInScreen: hitRadiusInScreen,
            context: context
        ) {
            return
        }

        selectCompletedSession(
            at: screenPoint,
            mapper: mapper,
            hitRadiusInScreen: hitRadiusInScreen,
            context: context
        )
    }

    @discardableResult
    private func selectDailyRewardStar(
        at screenPoint: CGPoint,
        mapper: MySkyCoordinateMapper,
        hitRadiusInScreen: CGFloat,
        context: Context
    ) -> Bool {
        var bestMatch: (star: DailyStarItem, distance: CGFloat)?

        for star in context.dailyStars {
            let position = mapper.screenPoint(
                fromSky: star.position,
                camera: context.cameraState.wrappedValue
            )
            let distance = hypot(position.x - screenPoint.x, position.y - screenPoint.y)
            guard distance <= hitRadiusInScreen else { continue }
            if let bestMatch, bestMatch.distance <= distance { continue }
            bestMatch = (star, distance)
        }

        guard let bestMatch else { return false }

        withAnimation(.easeInOut(duration: 0.2)) {
            if context.selectedDailyStar?.id == bestMatch.star.id {
                context.onSelectDailyStar(nil)
            } else {
                context.onSelectDailyStar(bestMatch.star)
            }
            context.selectedSession.wrappedValue = nil
        }
        return true
    }

    private func selectCompletedSession(
        at screenPoint: CGPoint,
        mapper: MySkyCoordinateMapper,
        hitRadiusInScreen: CGFloat,
        context: Context
    ) {
        var bestMatch: (session: FocusSession, distance: CGFloat)?

        for session in context.completedSessions {
            guard context.completionConstellationId != session.constellationId,
                  context.liveConstellationId != session.constellationId,
                  let constellation = context.constellationById(session.constellationId) else {
                continue
            }

            for star in constellation.stars {
                let starScreen = mapper.screenPoint(
                    fromSky: CGPoint(x: star.x, y: star.y),
                    camera: context.cameraState.wrappedValue
                )
                let distance = hypot(
                    starScreen.x - screenPoint.x,
                    starScreen.y - screenPoint.y
                )

                guard distance <= hitRadiusInScreen else { continue }
                if let bestMatch, bestMatch.distance <= distance { continue }
                bestMatch = (session, distance)
            }
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            if let bestMatch {
                context.selectedSession.wrappedValue = bestMatch.session
                context.onSelectDailyStar(nil)
            } else {
                context.selectedSession.wrappedValue = nil
                context.onSelectDailyStar(nil)
            }
        }
    }

    private func registerDragPressureSample(
        now: CFTimeInterval,
        translation: CGSize,
        context: Context
    ) {
        if now < pressureDetectionCooldownUntil {
            resetDragPressureState()
            lastRawDragSampleTime = now
            lastRawDragTranslation = translation
            context.onInputStressChanged(0)
            return
        }

        if lastRawDragSampleTime == 0 {
            lastRawDragSampleTime = now
            lastRawDragTranslation = translation
            context.onInputStressChanged(0)
            return
        }

        let dt = max(1.0 / 240.0, now - lastRawDragSampleTime)
        let delta = CGSize(
            width: translation.width - lastRawDragTranslation.width,
            height: translation.height - lastRawDragTranslation.height
        )
        let distance = hypot(delta.width, delta.height)
        let velocity = CGFloat(distance / dt)

        if velocity > stressVelocityStart {
            overloadAccumulatedDuration += CGFloat(dt)
        } else {
            overloadAccumulatedDuration = max(0, overloadAccumulatedDuration - (CGFloat(dt) * overloadDecayMultiplier))
        }

        let stressScore = min(max(overloadAccumulatedDuration / overloadTriggerDuration, 0), 1)
        context.onInputStressChanged(stressScore)

        lastRawDragSampleTime = now
        lastRawDragTranslation = translation

        if overloadAccumulatedDuration >= overloadTriggerDuration {
            overloadAccumulatedDuration = CGFloat(0)
            context.onInputStressChanged(0)
            enterInputPressureModeIfNeeded(now: now, context: context)
            return
        }

        if isInputPressureMode {
            pressureRecoveryTask?.cancel()
            pressureRecoveryTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(self.pressureRecoveryDelay))
                guard !Task.isCancelled else { return }
                self.releaseInputPressureModeIfNeeded()
            }
        }
    }

    private func enterInputPressureModeIfNeeded(now: CFTimeInterval, context: Context) {
        guard !isInputPressureMode else { return }
        isInputPressureMode = true
        pressureDetectionCooldownUntil = now + pressureDetectionCooldown
        resetDragPressureState()
        context.onInputPressureDetected()
    }

    private func releaseInputPressureModeIfNeeded() {
        pressureRecoveryTask?.cancel()
        pressureRecoveryTask = nil
        guard isInputPressureMode else { return }
        isInputPressureMode = false
        resetDragPressureState()
    }

    private func resetDragPressureState() {
        lastRawDragSampleTime = 0
        lastRawDragTranslation = .zero
        overloadAccumulatedDuration = 0
    }
}
