// 💡 SkySceneViewModel 클래스 전체 수정 (처음 보여주신 코드 기준)
import SwiftUI
import CoreGraphics
import Combine
import CoreMotion

@MainActor
final class SkySceneViewModel: ObservableObject {
    @Published var zoomScale: CGFloat = 0.72
    @Published var zoomAnchor: CGFloat = 0.72
    @Published var panOffset: CGSize = .zero
    @Published var lastPanTranslation: CGSize = .zero
    @Published var isInteracting: Bool = false
    @Published var frozenTime: TimeInterval = Date().timeIntervalSinceReferenceDate
    @Published var ambientStars: [StarObject] = []
    @Published var constellations: [Constellation] = []
    @Published var renderSize: CGSize?

    private let seed: UInt64
    private var cancellables = Set<AnyCancellable>() // Combine 구독 저장소
    private let sessionStore = SessionStore.shared   // 공유 스토어 참조

    // 💡 변경: init에서 하늘을 한 번 그리고, 이후 Store의 변화를 감지하도록 설정합니다.
    init(seed: UInt64) {
        self.seed = seed
        
        // 초기화 시점에 현재 기록 개수로 하늘 그리기
        regenerateSky(recordCount: sessionStore.dailyRecords.count)
        
        // 💡 Combine: SessionStore의 dailyRecords 배열이 변경될 때마다 하늘 다시 그리기
        sessionStore.$dailyRecords
            .receive(on: RunLoop.main) // 메인 스레드에서 실행 보장
            .sink { [weak self] records in
                guard let self = self else { return }
                // 기록 개수가 바뀌면 하늘 재생성
                self.regenerateSky(recordCount: records.count)
            }
            .store(in: &cancellables)
    }

    // 💡 추가: 하늘을 생성/재생성하는 헬퍼 메서드
    private func regenerateSky(recordCount: Int) {
        var generator = SkyGenerator()
        // 변경된 generator를 사용하여 기록 개수만큼 별자리 생성
        let data = generator.generate(seed: seed, recordCount: recordCount)
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
    
    @StateObject private var motion = MotionManager.shared
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
                    .animation(nil, value: motion.offset)
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
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
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
                .blur(radius: 60)

            Circle()
                .fill(Color(red: 0.38, green: 0.28, blue: 0.68).opacity(0.16))
                .frame(width: maxRadius * 1.6, height: maxRadius * 1.6)
                .position(x: size.width * 0.82, y: size.height * 0.8)
                .blur(radius: 70)
        }
    }

    @ViewBuilder
    func skyCanvas(size: CGSize) -> some View {
        let base = ZStack {
            ForEach(stars) { star in
                starView(star: star, size: size)
                    .offset(x: motion.offset.width, y: motion.offset.height)
                    .animation(nil, value: motion.offset)
            }

            ForEach(constellations) { constellation in
                ConstellationView(
                    constellation: constellation,
                    size: size,
                    timeOverride: model.isInteracting ? model.frozenTime : nil
                )
                .offset(x: motion.offset.width * 0.5, y: motion.offset.height * 0.5)
                .animation(nil, value: motion.offset)
            }

            ShootingStarLayer(size: size)
                .offset(x: motion.offset.width, y: motion.offset.height)
                .animation(nil, value: motion.offset)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)

        base
    }

    @ViewBuilder
    func starView(star: StarObject, size: CGSize) -> some View {
        let position = CGPoint(x: star.position.x * size.width, y: star.position.y * size.height)
        if showsTwinkle {
            TwinklingStar(
                position: position,
                size: 8,
                phaseOffset: Double(star.position.x * 10 + star.position.y * 20),
                color: star.color,
                timeOverride: model.isInteracting ? model.frozenTime : nil
            )
        } else {
            StaticStar(position: position, color: star.color)
        }
    }

    func panGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !model.isInteracting {
                    model.isInteracting = true
                    model.frozenTime = Date().timeIntervalSinceReferenceDate
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
                    model.frozenTime = Date().timeIntervalSinceReferenceDate
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

@MainActor
final class MotionManager: ObservableObject {
    static let shared = MotionManager()

    @Published var offset: CGSize = .zero

    private let manager = CMMotionManager()
    private let maxOffset: CGFloat = 18

    func start() {
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            offset = .zero
            return
        }
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let roll = CGFloat(motion.attitude.roll)
            let pitch = CGFloat(motion.attitude.pitch)
            let dx = min(max(roll * 20, -self.maxOffset), self.maxOffset)
            let dy = min(max(-pitch * 20, -self.maxOffset), self.maxOffset)
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                self.offset = CGSize(width: dx, height: dy)
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        offset = .zero
    }
}
