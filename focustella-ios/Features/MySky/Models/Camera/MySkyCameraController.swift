import SwiftUI

struct MySkyCameraController {
    let mapper: MySkyCoordinateMapper

    func skyPoint(at screenLocation: CGPoint, camera: MySkyCameraState) -> CGPoint {
        mapper.skyPoint(fromScreen: screenLocation, camera: camera)
    }

    func centeredCamera(forSky point: CGPoint, zoom: CGFloat) -> MySkyCameraState {
        MySkyCameraState(centerSky: point, zoom: clampedZoom(zoom))
    }

    func centeredCamera(forStar star: Star, zoom: CGFloat) -> MySkyCameraState {
        centeredCamera(forSky: CGPoint(x: star.x, y: star.y), zoom: zoom)
    }

    func centeredCamera(forConstellation constellation: Constellation, zoom: CGFloat) -> MySkyCameraState {
        centeredCamera(forSky: ConstellationGeometry(constellation: constellation).visualFocusPoint, zoom: zoom)
    }

    func overviewCamera(
        for constellation: Constellation,
        padding: CGFloat = 72,
        minimumZoom: CGFloat = 0.22,
        maximumZoom: CGFloat = 1.0
    ) -> MySkyCameraState {
        let bounds = ConstellationGeometry(constellation: constellation).normalizedBounds

        guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else {
            return centeredCamera(forConstellation: constellation, zoom: maximumZoom)
        }

        let contentWidth = max(1, bounds.width * mapper.skyCanvasSide)
        let contentHeight = max(1, bounds.height * mapper.skyCanvasSide)
        let availableWidth = max(1, mapper.canvasSize.width - padding * 2)
        let availableHeight = max(1, mapper.canvasSize.height - padding * 2)
        let fitZoom = min(availableWidth / contentWidth, availableHeight / contentHeight)
        return centeredCamera(
            forSky: ConstellationGeometry(constellation: constellation).visualFocusPoint,
            zoom: min(maximumZoom, max(minimumZoom, fitZoom))
        )
    }

    func dragging(camera: MySkyCameraState, translation: CGSize) -> MySkyCameraState {
        let deltaX = translation.width / (mapper.skyCanvasSide * max(camera.zoom, 0.0001))
        let deltaY = translation.height / (mapper.skyCanvasSide * max(camera.zoom, 0.0001))
        return MySkyCameraState(
            centerSky: CGPoint(x: camera.centerSky.x - deltaX, y: camera.centerSky.y - deltaY),
            zoom: camera.zoom
        )
    }

    func magnifying(camera: MySkyCameraState, magnification: CGFloat) -> MySkyCameraState {
        MySkyCameraState(centerSky: camera.centerSky, zoom: clampedZoom(camera.zoom * magnification))
    }

    private func clampedZoom(_ zoom: CGFloat) -> CGFloat {
        min(max(zoom, 0.22), 2.0)
    }
}
