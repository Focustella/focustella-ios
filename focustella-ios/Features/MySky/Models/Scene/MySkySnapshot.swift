import CoreGraphics
import Foundation

struct MySkySnapshot {
    let seed: Int64
    let dailyStars: [CGPoint]
    let remoteFocusLayoutItems: [FocusSkyLayoutItem]
    let completedSessions: [FocusSession]
    let constellations: [Constellation]
}
