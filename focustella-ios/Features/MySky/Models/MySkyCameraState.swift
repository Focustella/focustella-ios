import CoreGraphics

struct MySkyCameraState: Equatable {
    var centerSky: CGPoint
    var zoom: CGFloat

    static let `default` = MySkyCameraState(centerSky: CGPoint(x: 0.5, y: 0.5), zoom: 1.0)
}
