import Foundation
import CoreGraphics

struct StarBirthEffectStyle: Hashable {
    let preludeDuration: TimeInterval
    let condenseDuration: TimeInterval
    let birthDuration: TimeInterval
    let settleDuration: TimeInterval
    let holdDuration: TimeInterval
    let fadeOutDuration: TimeInterval
    let particleCount: Int
    let ringStartRadius: CGFloat
    let ringEndRadius: CGFloat
    let effectScale: CGFloat
    let connectionResponseDuration: TimeInterval

    var totalDuration: TimeInterval {
        preludeDuration + condenseDuration + birthDuration + settleDuration + holdDuration + fadeOutDuration
    }

    static let minimal = StarBirthEffectStyle(
        preludeDuration: 0.4,
        condenseDuration: 0.5,
        birthDuration: 0.28,
        settleDuration: 0.62,
        holdDuration: 0.18,
        fadeOutDuration: 0.34,
        particleCount: 5,
        ringStartRadius: 8,
        ringEndRadius: 20,
        effectScale: 1.18,
        connectionResponseDuration: 0.42
    )
}

struct StarBirthSegment: Hashable {
    let from: CGPoint
    let to: CGPoint
}
