import CoreGraphics
import Foundation

struct MySkySnapshot {
    let seed: Int64
    let dailyStars: [CGPoint]
    let completedSessions: [FocusSession]
    let constellations: [Constellation]
}
