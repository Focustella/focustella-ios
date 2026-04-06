import SwiftUI

@MainActor
final class MySkyInteractionController {
    struct Context {
        var cameraState: Binding<MySkyCameraState>
        var dragStartCamera: Binding<MySkyCameraState?>
        var magnifyStartZoom: Binding<CGFloat?>
        var selectedSession: Binding<FocusSession?>
        var selectedDailyStar: Binding<DailyStarItem?>

        let completionConstellationId: UUID?
        let liveConstellationId: UUID?
        let completedSessions: [FocusSession]
        let canvasSize: CGSize

        let coordinateMapper: (CGSize) -> MySkyCoordinateMapper
        let cameraController: (CGSize) -> MySkyCameraController
        let constellationById: (UUID) -> Constellation?
        let onInteractionBegan: () -> Void
        let onInteractionEnded: () -> Void
    }

    func dragGesture(context: Context) -> some Gesture {
        DragGesture()
            .onChanged { value in
                context.onInteractionBegan()
                if context.dragStartCamera.wrappedValue == nil {
                    context.dragStartCamera.wrappedValue = context.cameraState.wrappedValue
                }
                context.cameraState.wrappedValue = context.cameraController(context.canvasSize).dragging(
                    camera: context.dragStartCamera.wrappedValue ?? context.cameraState.wrappedValue,
                    translation: value.translation
                )
            }
            .onEnded { _ in
                context.dragStartCamera.wrappedValue = nil
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
                context.cameraState.wrappedValue = MySkyCameraState(
                    centerSky: context.cameraState.wrappedValue.centerSky,
                    zoom: min(max((context.magnifyStartZoom.wrappedValue ?? context.cameraState.wrappedValue.zoom) * value, 0.22), 2.0)
                )
            }
            .onEnded { _ in
                context.magnifyStartZoom.wrappedValue = nil
                context.onInteractionEnded()
            }
    }

    func sessionTapGesture(size: CGSize, context: Context) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                self.selectCompletedSession(
                    at: value.location,
                    size: size,
                    context: context
                )
            }
    }

    private func selectCompletedSession(
        at screenPoint: CGPoint,
        size: CGSize,
        context: Context
    ) {
        let mapper = context.coordinateMapper(size)
        let hitRadiusInScreen = max(24, 44 / max(context.cameraState.wrappedValue.zoom, 0.22))

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
                context.selectedDailyStar.wrappedValue = nil
            } else {
                context.selectedSession.wrappedValue = nil
            }
        }
    }
}
