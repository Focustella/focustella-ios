import SwiftUI

struct FourPointStarShape: Shape {
    var insetRatio: CGFloat = 0.35
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let width = rect.width; let height = rect.height
        
        let top = CGPoint(x: center.x, y: 0)
        let bottom = CGPoint(x: center.x, y: height)
        let left = CGPoint(x: 0, y: center.y)
        let right = CGPoint(x: width, y: center.y)
        
        let innerTopLeft = CGPoint(x: center.x - width * insetRatio / 2, y: center.y - height * insetRatio / 2)
        let innerTopRight = CGPoint(x: center.x + width * insetRatio / 2, y: center.y - height * insetRatio / 2)
        let innerBottomLeft = CGPoint(x: center.x - width * insetRatio / 2, y: center.y + height * insetRatio / 2)
        let innerBottomRight = CGPoint(x: center.x + width * insetRatio / 2, y: center.y + height * insetRatio / 2)

        var path = Path()
        path.move(to: top)
        path.addQuadCurve(to: right, control: innerTopRight)
        path.addQuadCurve(to: bottom, control: innerBottomRight)
        path.addQuadCurve(to: left, control: innerBottomLeft)
        path.addQuadCurve(to: top, control: innerTopLeft)
        path.closeSubpath()
        return path
    }
}

struct ElegantStarView: View {
    let color: Color
    let size: CGFloat
    
    var body: some View {
        ZStack {
            FourPointStarShape(insetRatio: 0.4)
                .fill(color.opacity(0.4))
                .frame(width: size, height: size)
                .blur(radius: size * 0.15)
            
            FourPointStarShape(insetRatio: 0.35)
                .fill(LinearGradient(colors: [.white, color], startPoint: .center, endPoint: .bottomTrailing))
                .frame(width: size * 0.8, height: size * 0.8)
                .rotationEffect(.degrees(-5))
        }
    }
}
