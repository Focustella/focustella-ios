import SwiftUI

struct ShootingStarLayer: View {
    let size: CGSize
    @State private var scheduled: ShootingStarEvent = .random()

    var body: some View {
        TimelineView(.animation) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let endTime = scheduled.startTime + scheduled.duration
            let isActive = now >= scheduled.startTime && now <= endTime

            ZStack {
                if isActive {
                    ShootingStar(
                        size: size,
                        start: scheduled.startPoint,
                        end: scheduled.endPoint,
                        progress: (now - scheduled.startTime) / scheduled.duration
                    )
                }
            }
            .onChange(of: isActive) { _, active in
                if !active && now > endTime {
                    scheduled = .random(after: now)
                }
            }
        }
    }
}

struct ShootingStarEvent {
    let startTime: TimeInterval
    let duration: TimeInterval
    let startPoint: CGPoint
    let endPoint: CGPoint

    static func random(after time: TimeInterval = Date().timeIntervalSinceReferenceDate) -> ShootingStarEvent {
        let delay = Double.random(in: 4.0...12.0)
        let duration = Double.random(in: 0.5...0.9)
        let startX = Double.random(in: -0.25...1.25)
        let startY = Double.random(in: -0.35 ... -0.05)
        let endX = Double.random(in: -0.25...1.25)
        let endY = Double.random(in: 1.05...1.35)

        let start = CGPoint(x: startX, y: startY)
        let end = CGPoint(x: endX, y: endY)
        return ShootingStarEvent(
            startTime: time + delay,
            duration: duration,
            startPoint: start,
            endPoint: end
        )
    }
}

struct ShootingStar: View {
    let size: CGSize
    let start: CGPoint
    let end: CGPoint
    let progress: Double

    var body: some View {
        let startPoint = CGPoint(x: start.x * size.width, y: start.y * size.height)
        let endPoint = CGPoint(x: end.x * size.width, y: end.y * size.height)
        let t = max(0, min(1, progress))
        let x = startPoint.x + (endPoint.x - startPoint.x) * t
        let y = startPoint.y + (endPoint.y - startPoint.y) * t

        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let tailLength: CGFloat = 140
        let tailOffset = CGPoint(x: cos(angle) * tailLength * 0.5, y: sin(angle) * tailLength * 0.5)
        let tailPosition = CGPoint(x: x - tailOffset.x, y: y - tailOffset.y)

        return Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.97, blue: 0.8, opacity: 0.0),
                        Color(red: 1.0, green: 0.97, blue: 0.8, opacity: 0.9)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: tailLength, height: 2)
            .rotationEffect(.radians(angle))
            .position(x: tailPosition.x, y: tailPosition.y)
            .shadow(color: Color(red: 1.0, green: 0.98, blue: 0.9, opacity: 0.6), radius: 6)
            .opacity(0.9)
    }
}
