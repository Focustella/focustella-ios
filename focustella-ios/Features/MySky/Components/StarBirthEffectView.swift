import SwiftUI

struct StarBirthEffectView: View {
    let position: CGPoint
    let connectionSegments: [StarBirthSegment]
    let reduceMotion: Bool
    var style: StarBirthEffectStyle = .minimal

    @State private var prelude: CGFloat = 0
    @State private var condense: CGFloat = 0
    @State private var birth: CGFloat = 0
    @State private var settle: CGFloat = 0
    @State private var connectionPulse: CGFloat = 0
    @State private var masterOpacity: CGFloat = 1

    var body: some View {
        ZStack {
            ForEach(Array(connectionSegments.enumerated()), id: \.offset) { index, segment in
                let itemDelay = Double(index) * 0.03
                let local = max(0, min(1, connectionPulse - CGFloat(itemDelay / max(0.001, style.connectionResponseDuration))))
                let eased = local * local * (3 - 2 * local)
                Path { path in
                    path.move(to: segment.from)
                    path.addLine(to: segment.to)
                }
                .stroke(
                    Color.white.opacity(0.22 * eased),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color.white.opacity(0.18 * eased), radius: 2.4 * eased)
            }

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.16 * prelude))
                    .frame(width: 72, height: 72)
                    .blur(radius: 20 * prelude)

                ForEach(0..<style.particleCount, id: \.self) { index in
                    let angle = (Double(index) / Double(style.particleCount)) * .pi * 2
                    let swirl = reduceMotion ? 0 : Double(condense) * 0.9
                    let radius = (28 - (24 * condense))
                    let x = cos(angle + swirl) * radius
                    let y = sin(angle + swirl) * radius

                    Circle()
                        .fill(Color.white.opacity(0.18 + 0.42 * (1 - condense)))
                        .frame(width: reduceMotion ? 2.8 : 3.6, height: reduceMotion ? 2.8 : 3.6)
                        .blur(radius: reduceMotion ? 0.5 : 1.2)
                        .offset(x: x, y: y)
                }

                Circle()
                    .fill(Color.white.opacity(0.22 + 0.62 * condense))
                    .frame(width: 12, height: 12)
                    .scaleEffect(0.6 + 0.5 * birth)
                    .blur(radius: 1.6 + (4.0 * condense))

                // Short star flare at ignition.
                Group {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.white.opacity(0.75 * birth), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 32, height: 1)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.white.opacity(0.75 * birth), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 1, height: 32)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.white.opacity(0.45 * birth), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 22, height: 1)
                        .rotationEffect(.degrees(45))
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.white.opacity(0.45 * birth), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 22, height: 1)
                        .rotationEffect(.degrees(-45))
                }
                .blur(radius: 0.6)

                Circle()
                    .stroke(Color.white.opacity(0.22 * birth), lineWidth: 1.2)
                    .frame(width: style.ringStartRadius, height: style.ringStartRadius)
                    .scaleEffect(1 + (style.ringEndRadius / max(1, style.ringStartRadius) * birth))
                    .opacity(1 - birth)

                ForEach(0..<3, id: \.self) { index in
                    let baseAngle = (Double(index) / 3.0) * .pi * 2
                    let drift = CGFloat(12 + (index * 4)) * settle
                    Circle()
                        .fill(Color.white.opacity(0.24 * (1 - settle)))
                        .frame(width: 2.6, height: 2.6)
                        .offset(
                            x: cos(baseAngle) * drift,
                            y: sin(baseAngle) * drift
                        )
                        .blur(radius: 0.8)
                }
            }
            .position(position)
            .scaleEffect(style.effectScale, anchor: .center)
        }
        .opacity(masterOpacity)
        .onAppear {
            runSequence()
        }
    }

    private func runSequence() {
        withAnimation(.easeOut(duration: style.preludeDuration)) {
            prelude = 1
        }

        withAnimation(.easeInOut(duration: style.condenseDuration).delay(style.preludeDuration * 0.5)) {
            condense = 1
        }

        withAnimation(.interpolatingSpring(stiffness: 210, damping: 20).delay(style.preludeDuration + style.condenseDuration * 0.55)) {
            birth = 1
        }

        withAnimation(.easeOut(duration: style.settleDuration).delay(style.preludeDuration + style.condenseDuration + style.birthDuration * 0.35)) {
            settle = 1
        }

        withAnimation(.easeOut(duration: style.connectionResponseDuration).delay(style.preludeDuration + style.condenseDuration + 0.1)) {
            connectionPulse = 1
        }

        let fadeDelay = style.preludeDuration + style.condenseDuration + style.birthDuration + style.settleDuration + style.holdDuration
        withAnimation(.easeOut(duration: style.fadeOutDuration).delay(fadeDelay)) {
            masterOpacity = 0
        }
    }
}
