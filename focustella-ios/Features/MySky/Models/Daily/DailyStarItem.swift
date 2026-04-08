import Foundation
import CoreGraphics

struct DailyStarItem: Identifiable, Equatable {
    let id = UUID()
    let position: CGPoint
    let date: Date
}
