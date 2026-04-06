import CoreGraphics

struct MySkyEdgeRevealState {
    var committedDiscoveredCount: Int = 0
    var pendingDiscoveredCount: Int?
    var progress: CGFloat = 0
}
