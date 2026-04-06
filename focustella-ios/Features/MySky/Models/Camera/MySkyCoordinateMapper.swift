import SwiftUI

struct MySkyCoordinateMapper: Hashable {
    let canvasSize: CGSize

    var skyCanvasSide: CGFloat {
        max(1, min(canvasSize.width, canvasSize.height))
    }

    var canvasOrigin: CGPoint {
        CGPoint(
            x: (canvasSize.width - skyCanvasSide) / 2,
            y: (canvasSize.height - skyCanvasSide) / 2
        )
    }

    var screenCenter: CGPoint {
        CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
    }

    func canvasPoint(fromSky point: CGPoint) -> CGPoint {
        CGPoint(
            x: canvasOrigin.x + point.x * skyCanvasSide,
            y: canvasOrigin.y + point.y * skyCanvasSide
        )
    }

    func skyPoint(fromCanvas point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x - canvasOrigin.x) / skyCanvasSide,
            y: (point.y - canvasOrigin.y) / skyCanvasSide
        )
    }

    func canvasPoint(for star: Star) -> CGPoint {
        canvasPoint(fromSky: CGPoint(x: star.x, y: star.y))
    }

    func renderOffset(for camera: MySkyCameraState) -> CGSize {
        let canvasCenter = canvasPoint(fromSky: camera.centerSky)
        return CGSize(
            width: (screenCenter.x - canvasCenter.x) * camera.zoom,
            height: (screenCenter.y - canvasCenter.y) * camera.zoom
        )
    }

    func screenPoint(fromCanvas point: CGPoint, camera: MySkyCameraState) -> CGPoint {
        let offset = renderOffset(for: camera)
        return CGPoint(
            x: screenCenter.x + ((point.x - screenCenter.x) * camera.zoom) + offset.width,
            y: screenCenter.y + ((point.y - screenCenter.y) * camera.zoom) + offset.height
        )
    }

    func screenPoint(fromSky point: CGPoint, camera: MySkyCameraState) -> CGPoint {
        screenPoint(fromCanvas: canvasPoint(fromSky: point), camera: camera)
    }

    func skyPoint(fromScreen point: CGPoint, camera: MySkyCameraState) -> CGPoint {
        let offset = renderOffset(for: camera)
        let canvasPoint = CGPoint(
            x: ((point.x - offset.width - screenCenter.x) / max(camera.zoom, 0.0001)) + screenCenter.x,
            y: ((point.y - offset.height - screenCenter.y) / max(camera.zoom, 0.0001)) + screenCenter.y
        )
        return skyPoint(fromCanvas: canvasPoint)
    }
}
