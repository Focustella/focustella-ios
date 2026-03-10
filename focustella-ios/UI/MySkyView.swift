import SwiftUI
import Combine

struct MySkyView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var accessibility = AppAccessibility.shared
    @AppStorage("highPerformanceMode") private var highPerformanceMode: Bool = false
    @AppStorage("developerMode") private var developerMode: Bool = false

    private let repository = ConstellationRepository()
    private let scheduler = DiscoveryScheduler()

    @State private var scale: CGFloat = 1.0
    @State private var scaleAnchor: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastDrag: CGSize = .zero
    @State private var isInteracting = false

    @State private var showCTA = true
    @State private var ctaTask: Task<Void, Never>?
    @State private var showSlotPicker = false
    @State private var showDailySessionNotice = false

    @State private var selectedSession: FocusSession?
    @State private var completionConstellation: Constellation?
    @State private var pendingMemoSessionId: UUID?
    @State private var showMemoSheet = false
    @State private var hasLaidOutCTA = false
    @State private var placedConstellations: [Constellation] = []
    @State private var previewConstellations: [Constellation] = []
    
    private let ctaFadeDuration: Double = 0.38
    private let ctaIdleDelay: Double = 1.5

    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let ambientStars: [AmbientStar] = AmbientStar.makeSeeded(count: 90, seed: 20260308)
    private let mockUserId = "mock-user-001"

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.24),
                        Color(red: 0.04, green: 0.06, blue: 0.16),
                        Color(red: 0.02, green: 0.03, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                Circle()
                    .fill(Color(red: 0.25, green: 0.38, blue: 0.78).opacity(0.2))
                    .frame(width: size.width * 0.9, height: size.width * 0.9)
                    .position(x: size.width * 0.2, y: size.height * 0.16)
                    .blur(radius: 70)
                    .allowsHitTesting(false)

                Circle()
                    .fill(Color(red: 0.36, green: 0.3, blue: 0.66).opacity(0.14))
                    .frame(width: size.width * 1.0, height: size.width * 1.0)
                    .position(x: size.width * 0.82, y: size.height * 0.84)
                    .blur(radius: 78)
                    .allowsHitTesting(false)

                ZStack {
                    ambientStarLayer(size: size)
                    skyCanvas(size: size)
                }
                .scaleEffect(scale)
                .offset(offset)
                .animation(nil, value: scale)
                .animation(nil, value: offset)
                .contentShape(Rectangle())
                .gesture(dragGesture())
                .simultaneousGesture(magnificationGesture())
                .simultaneousGesture(tapGesture(size: size))

                if let session = sessionStore.currentSession,
                   let constellation = constellationById(session.constellationId) {
                    VStack {
                        Spacer()
                        FocusSessionOverlay(
                            session: session,
                            constellation: constellation,
                            remainingSeconds: sessionStore.remainingSeconds(),
                            reduceMotion: accessibility.isReduceMotionEnabled,
                            highPerformanceMode: highPerformanceMode,
                            isDeveloperMode: developerMode,
                            onPause: {
                                registerInteraction()
                                sessionStore.pause()
                            },
                            onResume: {
                                registerInteraction()
                                let remainingStars = max(0, constellation.starCount - session.discoveredStarCount)
                                let remainingTime = TimeInterval(sessionStore.remainingSeconds())
                                _ = scheduler.intervalAfterResume(remainingTime: remainingTime, remainingStars: remainingStars)
                                sessionStore.resume(remainingStars: remainingStars)
                            },
                            onCancel: {
                                registerInteraction()
                                if let constellationId = sessionStore.currentSession?.constellationId {
                                    placedConstellations.removeAll { $0.id == constellationId }
                                }
                                sessionStore.cancel()
                                scheduleCTA()
                            },
                            onAdvanceNextStar: {
                                let result = sessionStore.advanceToNextStar(totalStars: constellation.starCount)
                                if result.advanced {
                                    Haptics.light()
                                }
                                if let completed = result.completed {
                                    Haptics.success()
                                    pendingMemoSessionId = completed.id
                                    completionConstellation = constellation
                                    selectedSession = completed
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .transition(.opacity)
                }

                if let session = selectedSession,
                   let constellation = constellationById(session.constellationId) {
                    sessionDetailCard(session: session, constellation: constellation)
                        .padding(.horizontal, 20)
                        .padding(.top, 72)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let constellation = completionConstellation {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()

                    CompletionAnimation(
                        constellation: constellation,
                        reduceMotion: accessibility.isReduceMotionEnabled,
                        highPerformanceMode: highPerformanceMode,
                        onFinished: {
                            completionConstellation = nil
                            showMemoSheet = true
                        }
                    )
                    .frame(width: size.width * 0.9, height: size.height * 0.68)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("MySky")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                showCTA = sessionStore.currentSession == nil
                hasLaidOutCTA = true
                loadPreviewConstellations()
            }
            .onReceive(tick) { now in syncSession(now: now) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    syncSession(now: Date())
                    scheduleCTA()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didInsertUserConstellation)) { _ in
                loadPreviewConstellations()
            }
            .sheet(isPresented: $showSlotPicker) {
                SlotPickerSheet { seconds in
                    requestStartSession(slotSeconds: seconds)
                }
            }
            .alert("일일 세션", isPresented: $showDailySessionNotice) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("일일 세션은 다음 단계에서 연결 예정입니다.")
            }
            .sheet(isPresented: $showMemoSheet) {
                MemoSheet { memo in
                    if let sessionId = pendingMemoSessionId {
                        sessionStore.updateMemo(sessionId: sessionId, memo: memo)
                    }
                    pendingMemoSessionId = nil
                    selectedSession = nil
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        showDailySessionNotice = true
                    } label: {
                        Text("오늘 하루 계획하기")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 220, height: 48)
                            .background(Color.white.opacity(0.16), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showSlotPicker = true
                    } label: {
                        Text("집중 세션 시작")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(width: 220, height: 48)
                            .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 36)
                .opacity((showCTA && sessionStore.currentSession == nil) ? 1 : 0)
                .scaleEffect((showCTA && sessionStore.currentSession == nil) ? 1 : 0.98)
                .allowsHitTesting(showCTA && sessionStore.currentSession == nil)
                .animation(
                    hasLaidOutCTA ? .easeInOut(duration: ctaFadeDuration) : nil,
                    value: showCTA
                )
                .animation(
                    hasLaidOutCTA ? .easeInOut(duration: ctaFadeDuration) : nil,
                    value: sessionStore.currentSession == nil
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private func constellationById(_ id: UUID) -> Constellation? {
        placedConstellations.first { $0.id == id }
    }

    private func requestStartSession(slotSeconds: Int) {
        Task { @MainActor in
            guard sessionStore.currentSession == nil else { return }
            guard let constellation = await repository.fetchSessionConstellation(
                durationSeconds: slotSeconds,
                occupied: placedConstellations + previewConstellations,
                userId: mockUserId
            ) else { return }

            placedConstellations.append(constellation)
            sessionStore.startSession(slotSeconds: slotSeconds, constellationId: constellation.id)
            selectedSession = nil
            showCTA = false
        }
    }

    private func syncSession(now: Date) {
        guard let session = sessionStore.currentSession,
              let constellation = constellationById(session.constellationId) else {
            return
        }

        let result = sessionStore.refreshCurrentSession(now: now, totalStars: constellation.starCount, scheduler: scheduler)
        if result.newlyDiscovered && result.completed == nil {
            Haptics.light()
        }
        if let completed = result.completed {
            Haptics.success()
            pendingMemoSessionId = completed.id
            completionConstellation = constellation
            selectedSession = completed
        }
    }

    private func registerInteraction() {
        if showCTA {
            withAnimation(.easeInOut(duration: ctaFadeDuration)) {
                showCTA = false
            }
        }
        isInteracting = true
        ctaTask?.cancel()
    }

    private func endInteraction() {
        isInteracting = false
        scheduleCTA()
    }

    private func scheduleCTA() {
        ctaTask?.cancel()
        guard sessionStore.currentSession == nil else { return }

        ctaTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(ctaIdleDelay))
            guard !Task.isCancelled, !isInteracting, sessionStore.currentSession == nil else { return }
            withAnimation(.easeInOut(duration: ctaFadeDuration)) {
                showCTA = true
            }
        }
    }

    private func dragGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                registerInteraction()
                offset = CGSize(
                    width: offset.width + value.translation.width - lastDrag.width,
                    height: offset.height + value.translation.height - lastDrag.height
                )
                lastDrag = value.translation
            }
            .onEnded { _ in
                lastDrag = .zero
                endInteraction()
            }
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                registerInteraction()
                let next = scaleAnchor * value
                scale = min(max(next, 0.7), 2.0)
            }
            .onEnded { _ in
                scaleAnchor = scale
                endInteraction()
            }
    }

    private func tapGesture(size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                registerInteraction()
                defer { endInteraction() }

                let normalized = normalizeTap(value.location, size: size)
                var best: (session: FocusSession, distance: CGFloat)?

                for session in sessionStore.completedSessions {
                    guard let constellation = constellationById(session.constellationId) else { continue }
                    for star in constellation.stars {
                        let dx = star.x - normalized.x
                        let dy = star.y - normalized.y
                        let distance = sqrt(dx * dx + dy * dy)
                        if distance < 0.04 {
                            if let best, best.distance <= distance {
                                continue
                            }
                            best = (session, distance)
                        }
                    }
                }

                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedSession = best?.session
                }
            }
    }

    private func normalizeTap(_ location: CGPoint, size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let x = ((location.x - offset.width - center.x) / scale + center.x) / size.width
        let y = ((location.y - offset.height - center.y) / scale + center.y) / size.height
        return CGPoint(x: x, y: y)
    }

    @ViewBuilder
    private func ambientStarLayer(size: CGSize) -> some View {
        let shouldAnimate = highPerformanceMode && !accessibility.isReduceMotionEnabled
        TimelineView(.periodic(from: .now, by: shouldAnimate ? 1.0 / 6.0 : 1.2)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(ambientStars) { star in
                    let pulse = shouldAnimate ? (sin(t * 1.1 + star.phase) + 1) / 2 : 0.4
                    let opacity = shouldAnimate ? (star.baseOpacity + pulse * 0.25) : (star.baseOpacity * 0.85)
                    let glow = shouldAnimate ? (star.baseGlow + CGFloat(pulse) * 3.0) : (star.baseGlow * 0.6)

                    ZStack {
                        Circle()
                            .fill(star.color.opacity(opacity))
                            .frame(width: star.size, height: star.size)

                        if shouldAnimate && star.hasFlare {
                            AmbientStarFlare(
                                length: star.size * (2.4 + CGFloat(pulse)),
                                thickness: max(0.3, star.size * 0.12),
                                color: star.color.opacity(opacity * 0.4)
                            )
                            .rotationEffect(.degrees(star.flareAngle))
                        }
                    }
                    .shadow(color: star.color.opacity(0.5), radius: glow)
                    .position(x: star.x * size.width, y: star.y * size.height)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func skyCanvas(size: CGSize) -> some View {
        let activeConstellationIds = Set(
            sessionStore.completedSessions.map(\.constellationId) +
            [sessionStore.currentSession?.constellationId].compactMap { $0 }
        )

        ZStack {
            ForEach(previewConstellations) { constellation in
                if !activeConstellationIds.contains(constellation.id) {
                    ConstellationRenderer(
                        constellation: constellation,
                        discoveredStarCount: constellation.starCount,
                        showEdges: true,
                        edgeProgress: 1,
                        reduceMotion: accessibility.isReduceMotionEnabled,
                        highPerformanceMode: highPerformanceMode
                    )
                    .opacity(0.5)
                }
            }

            ForEach(sessionStore.completedSessions) { session in
                if let constellation = constellationById(session.constellationId) {
                    ConstellationRenderer(
                        constellation: constellation,
                        discoveredStarCount: constellation.starCount,
                        showEdges: true,
                        edgeProgress: 1,
                        reduceMotion: accessibility.isReduceMotionEnabled,
                        highPerformanceMode: highPerformanceMode
                    )
                }
            }

            if let running = sessionStore.currentSession,
               let constellation = constellationById(running.constellationId) {
                ConstellationRenderer(
                    constellation: constellation,
                    discoveredStarCount: running.discoveredStarCount,
                    showEdges: false,
                    edgeProgress: 0,
                    reduceMotion: accessibility.isReduceMotionEnabled,
                    highPerformanceMode: highPerformanceMode
                )
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func loadPreviewConstellations() {
        Task { @MainActor in
            let previews = await repository.fetchUserConstellations(
                userId: mockUserId,
                occupied: placedConstellations
            )
            previewConstellations = previews
        }
    }

    @ViewBuilder
    private func sessionDetailCard(session: FocusSession, constellation: Constellation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(constellation.name)
                    .font(.headline)
                Spacer()
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let endedAt = session.endedAt {
                Text("완료: \(endedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let memo = session.memo {
                Text("태그: \(memo.topicTags.joined(separator: ", "))")
                    .font(.caption)
                Text("성취도: \(String(repeating: "★", count: memo.rating))")
                    .font(.caption)
                if let text = memo.freeText, !text.isEmpty {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("메모 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSession = nil
            }
        }
    }
}

private struct AmbientStar: Identifiable {
    let id: UUID = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let phase: Double
    let baseOpacity: Double
    let baseGlow: CGFloat
    let color: Color
    let hasFlare: Bool
    let flareAngle: Double

    static func makeSeeded(count: Int, seed: UInt64) -> [AmbientStar] {
        var generator = SeededRNG(state: seed == 0 ? 0xA1B2C3D4 : seed)
        return (0..<count).map { _ in
            let x = generator.nextCGFloat(in: 0.02...0.98)
            let y = generator.nextCGFloat(in: 0.04...0.96)
            let size = generator.nextCGFloat(in: 1.5...3.3)
            let phase = generator.nextDouble(in: 0...(Double.pi * 2))
            let baseOpacity = generator.nextDouble(in: 0.16...0.42)
            let baseGlow = generator.nextCGFloat(in: 1.2...3.4)
            let color = ambientColor(index: Int(generator.next() % 4))
            let hasFlare = size > 2.5 && (generator.next() % 11 == 0)
            let flareAngle = generator.nextDouble(in: 0...180)
            return AmbientStar(
                x: x,
                y: y,
                size: size,
                phase: phase,
                baseOpacity: baseOpacity,
                baseGlow: baseGlow,
                color: color,
                hasFlare: hasFlare,
                flareAngle: flareAngle
            )
        }
    }

    private static func ambientColor(index: Int) -> Color {
        switch index {
        case 0:
            return Color(red: 0.78, green: 0.92, blue: 1.0)
        case 1:
            return Color(red: 0.72, green: 0.88, blue: 1.0)
        case 2:
            return Color(red: 0.86, green: 0.95, blue: 1.0)
        default:
            return Color(red: 0.82, green: 0.9, blue: 1.0)
        }
    }
}

private struct SeededRNG {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let ratio = Double(next() & 0xFFFF_FFFF) / Double(UInt32.max)
        return range.lowerBound + ratio * (range.upperBound - range.lowerBound)
    }

    mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let ratio = Double(next() & 0xFFFF_FFFF) / Double(UInt32.max)
        return range.lowerBound + CGFloat(ratio) * (range.upperBound - range.lowerBound)
    }
}

private struct AmbientStarFlare: View {
    let length: CGFloat
    let thickness: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, color, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: length, height: thickness)
                .blur(radius: thickness * 0.45)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, color, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: thickness, height: length)
                .blur(radius: thickness * 0.45)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    NavigationStack {
        MySkyView()
    }
}
