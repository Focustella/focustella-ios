import SwiftUI
import CoreGraphics
import Combine

@MainActor
final class SkySceneViewModel: ObservableObject {
    @Published var zoomScale: CGFloat = 0.72
    @Published var zoomAnchor: CGFloat = 0.72
    @Published var panOffset: CGSize = .zero
    @Published var lastPanTranslation: CGSize = .zero
    @Published var isInteracting: Bool = false
    @Published var ambientStars: [StarObject] = []
    @Published var constellations: [Constellation] = []
    @Published var renderSize: CGSize?

    init(seed: UInt64) {
        var generator = SkyGenerator()
        let data = generator.generate(seed: seed)
        self.ambientStars = data.stars
        self.constellations = data.constellations
    }

    func updateRenderSizeIfNeeded(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if renderSize == nil {
            renderSize = size
            return
        }
        if let current = renderSize, (size.width > current.width || size.height > current.height) {
            renderSize = size
        }
    }
}

struct SkyView: View {
    @ObservedObject var model: SkySceneViewModel
    let showsTitle: Bool
    let showsTwinkle: Bool
    let isInteractive: Bool
    
    // 💡 변경: 파라미터로 받지 않고, 저장소에서 직접 값을 읽어옵니다.
    @AppStorage("isDarkTheme") private var isDarkTheme: Bool = true
    
    private var stars: [StarObject] { model.ambientStars }
    private var constellations: [Constellation] { model.constellations }

    // init에서 isDarkTheme 파라미터 삭제!
    init(
        model: SkySceneViewModel,
        showsTitle: Bool = true,
        showsTwinkle: Bool = true,
        isInteractive: Bool = true
    ) {
        self.model = model
        self.showsTitle = showsTitle
        self.showsTwinkle = showsTwinkle
        self.isInteractive = isInteractive
    }

    var body: some View {
        // ... (body 내부는 아까와 동일하게 isDarkTheme ? .dark : .light 를 사용하는 코드 그대로 유지) ...
        // 만약 body 코드가 지워졌다면 바로 말씀해주세요!
        GeometryReader { proxy in
            let viewSize = proxy.size
            let squareSide = min(viewSize.width, viewSize.height)
            let maxRadius = squareSide * 1.4
            
            ZStack {
                Color.black
                    .ignoresSafeArea()

                // 1. Hard-guaranteed nebula layer rendered directly in SkyView.
                directNebulaLayer(size: viewSize, maxRadius: maxRadius)
                    .ignoresSafeArea()

                // 2. Existing background layer (kept for richer texture).
                NebulaBackground(size: viewSize, maxRadius: maxRadius)
                    .opacity(isDarkTheme ? 0.8 : 0.9)

                let canvasSize = CGSize(width: squareSide * 6.0, height: squareSide * 6.0)
                let baseOffset = CGSize(
                    width: (viewSize.width - canvasSize.width) / 2,
                    height: (viewSize.height - canvasSize.height) / 2
                )
                
                // 3. 별 & 별자리 레이어
                let content = skyCanvas(size: canvasSize)
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .scaleEffect(model.zoomScale)
                    .offset(
                        x: baseOffset.width + model.panOffset.width,
                        y: baseOffset.height + model.panOffset.height
                    )

                content
                    .animation(nil, value: model.panOffset)
                    .animation(nil, value: model.zoomScale)
                    .ignoresSafeArea()
            }
            .ignoresSafeArea()
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { model.updateRenderSizeIfNeeded(proxy.size) }
                    .onChange(of: proxy.size) { _, newSize in
                        model.updateRenderSizeIfNeeded(newSize)
                    }
            }
        )
        .contentShape(Rectangle())
        .transaction { $0.animation = nil }
        .gesture(isInteractive ? panGesture() : nil)
        .simultaneousGesture(isInteractive ? zoomGesture() : nil)
        .modifier(TitleModifier(showsTitle: showsTitle))
        // 다크 테마일 경우 기본 글씨/UI 색상을 흰색으로 강제
        .environment(\.colorScheme, isDarkTheme ? .dark : .light)
    }
}

// 프리뷰에서 다크 테마 확인해보기
#Preview {
    SkyView(model: SkySceneViewModel(seed: 1))
}

private struct TitleModifier: ViewModifier {
    let showsTitle: Bool

    func body(content: Content) -> some View {
        if showsTitle {
            content.navigationTitle("Sky")
        } else {
            content
        }
    }
}

private extension SkyView {
    @ViewBuilder
    func directNebulaLayer(size: CGSize, maxRadius: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let driftA = CGSize(
                width: CGFloat(sin(t * 0.08)) * 16,
                height: CGFloat(cos(t * 0.06)) * 12
            )
            let driftB = CGSize(
                width: CGFloat(cos(t * 0.07 + 1.3)) * 14,
                height: CGFloat(sin(t * 0.05 + 0.9)) * 10
            )

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.1, blue: 0.22).opacity(0.42),
                        Color(red: 0.03, green: 0.05, blue: 0.14).opacity(0.34),
                        Color.black.opacity(0.36)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color(red: 0.24, green: 0.38, blue: 0.72).opacity(0.24))
                    .frame(width: maxRadius * 1.8, height: maxRadius * 1.8)
                    .position(x: size.width * 0.18, y: size.height * 0.2)
                    .offset(driftA)
                    .blur(radius: 60)

                Circle()
                    .fill(Color(red: 0.38, green: 0.28, blue: 0.68).opacity(0.16))
                    .frame(width: maxRadius * 1.6, height: maxRadius * 1.6)
                    .position(x: size.width * 0.82, y: size.height * 0.8)
                    .offset(driftB)
                    .blur(radius: 70)
            }
        }
    }

    @ViewBuilder
    func skyCanvas(size: CGSize) -> some View {
        let base = ZStack {
            ForEach(stars) { star in
                starView(star: star, size: size)
            }

            ForEach(constellations) { constellation in
                ConstellationView(
                    constellation: constellation,
                    size: size,
                    timeOverride: nil
                )
            }

            ShootingStarLayer(size: size)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)

        base
    }

    @ViewBuilder
    func starView(star: StarObject, size: CGSize) -> some View {
        let position = CGPoint(x: star.position.x * size.width, y: star.position.y * size.height)
        if showsTwinkle {
            Circle()
                .fill(star.color.primary)
                .frame(width: 4, height: 4)
                .position(position)

            TwinklingStar(
                position: position,
                size: 13,
                phaseOffset: Double(star.position.x * 10 + star.position.y * 20),
                color: star.color,
                timeOverride: nil,
                animatesColor: false
            )
            .shadow(color: star.color.glow(opacity: 0.9), radius: 6)
        } else {
            StaticStar(position: position, color: star.color, animatesColor: false)
                .frame(width: 13, height: 13)
                .shadow(color: star.color.glow(opacity: 0.9), radius: 6)
        }
    }

    func panGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !model.isInteracting {
                    model.isInteracting = true
                }
                model.panOffset = CGSize(
                    width: model.panOffset.width + value.translation.width - model.lastPanTranslation.width,
                    height: model.panOffset.height + value.translation.height - model.lastPanTranslation.height
                )
                model.lastPanTranslation = value.translation
            }
            .onEnded { _ in
                model.lastPanTranslation = .zero
                model.isInteracting = false
            }
    }

    func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if !model.isInteracting {
                    model.isInteracting = true
                }
                let next = model.zoomAnchor * value
                model.zoomScale = min(max(next, 0.1), 1.6)
            }
            .onEnded { _ in
                model.zoomAnchor = model.zoomScale
                model.isInteracting = false
            }
    }
}
