// 📂 Features/MySky/Views/MySkyView.swift
import SwiftUI
import Combine
import os

struct MySkyView: View {
    private static let logger = Logger(subsystem: "focustella-ios", category: "FocusSession")

    private struct EdgeRevealState {
        var committedDiscoveredCount: Int = 0
        var pendingDiscoveredCount: Int?
        var progress: CGFloat = 0
    }

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var accessibility = AppAccessibility.shared
    @AppStorage("highPerformanceMode") private var highPerformanceMode: Bool = false
    @AppStorage("developerMode") private var developerMode: Bool = false
    @AppStorage("starStyle") private var starStyle: StarAppearanceStyle = .realistic
    
    // 🔥 튜토리얼 진행 상태 저장
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    @State private var tutorialStep: TutorialStep = .notStarted
    
    @AppStorage("dailyStarsData") private var dailyStarsData: String = ""
    @State private var dailyStars: [CGPoint] = []
    @State private var showDailyRewardText = false
    @State private var dailyStarRippleCenter: CGPoint?

    private let repository = ConstellationRepository()
    private let scheduler = DiscoveryScheduler()

    @State private var scale: CGFloat = 1.0
    @State private var scaleAnchor: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastDrag: CGSize = .zero
    @State private var isInteracting = false
    @State private var canvasSize: CGSize = .zero

    @State private var showCTA = true
    @State private var ctaTask: Task<Void, Never>?
    @State private var showSlotPicker = false
    @State private var showDailySessionSheet = false

    @State private var selectedSession: FocusSession?
    @State private var completionConstellation: Constellation?
    @State private var pendingMemoSessionId: UUID?
    @State private var showMemoSheet = false
    @State private var starBirthCenter: CGPoint?
    @State private var starBirthSegments: [StarBirthSegment] = []
    @State private var spawnEffectToken: Int = 0
    @State private var pendingCameraMoveTask: Task<Void, Never>?
    @State private var cameraTransitionTask: Task<Void, Never>?
    @State private var showCompletionOverlay = false
    @State private var showCompletionRecordButton = false
    @State private var completionFlowTask: Task<Void, Never>?
    @State private var completionEdgeOrder: [Int] = []
    @State private var hasLaidOutCTA = false
    @State private var placedConstellations: [Constellation] = []
    @State private var previewConstellations: [Constellation] = []
    @State private var visibleDiscoveredStarCounts: [UUID: Int] = [:]
    @State private var edgeRevealStates: [UUID: EdgeRevealState] = [:]
    @State private var edgeRevealTokens: [UUID: Int] = [:]
    
    private let ctaFadeDuration: Double = 0.38
    private let ctaIdleDelay: Double = 1.5
    private let sessionAutoZoom: CGFloat = 2.0
    private let completionEffectEnabled = false
    private let completionCameraMoveDuration: TimeInterval = 1.05

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let ambientStars: [AmbientStar] = AmbientStar.makeSeeded(count: 90, seed: 20260308)
    private let mockUserId = "mock-user-001"

    private var isSkyInteractionLocked: Bool {
        pendingMemoSessionId != nil || showMemoSheet || tutorialStep != .done
    }

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
                
                Circle().fill(Color(red: 0.25, green: 0.38, blue: 0.78).opacity(0.2))
                    .frame(width: size.width * 0.9, height: size.width * 0.9).position(x: size.width * 0.2, y: size.height * 0.16).blur(radius: 70).allowsHitTesting(false)
                
                Circle().fill(Color(red: 0.36, green: 0.3, blue: 0.66).opacity(0.14))
                    .frame(width: size.width * 1.0, height: size.width * 1.0).position(x: size.width * 0.82, y: size.height * 0.84).blur(radius: 78).allowsHitTesting(false)
                
                interactiveSkyLayer(size: size)
                
                if let birthCenter = starBirthCenter {
                    RippleEffectView(position: screenPoint(normalized: birthCenter, size: size), reduceMotion: accessibility.isReduceMotionEnabled)
                        .id("ripple-\(spawnEffectToken)")
                    
                    StarBirthEffectView(
                        position: screenPoint(normalized: birthCenter, size: size),
                        connectionSegments: starBirthSegments.map { StarBirthSegment(from: screenPoint(normalized: $0.from, size: size), to: screenPoint(normalized: $0.to, size: size)) },
                        reduceMotion: accessibility.isReduceMotionEnabled
                    )
                    .id(spawnEffectToken).allowsHitTesting(false)
                }
                
                if let rewardCenter = dailyStarRippleCenter {
                    RippleEffectView(position: screenPoint(normalized: rewardCenter, size: size), reduceMotion: accessibility.isReduceMotionEnabled)
                        .id("daily-ripple-\(spawnEffectToken)").allowsHitTesting(false)
                }
                
                if let session = sessionStore.currentSession, let constellation = constellationById(session.constellationId) {
                    VStack {
                        Spacer()
                        FocusSessionOverlay(
                            session: session,
                            remainingSeconds: sessionStore.remainingSeconds(),
                            isDeveloperMode: developerMode,
                            isTutorial: tutorialStep == .warping, // 🔥 튜토리얼 모드 주입
                            onPause: { sessionStore.pause() },
                            onResume: {
                                let remainingStars = max(0, constellation.starCount - session.discoveredStarCount)
                                let remainingTime = TimeInterval(sessionStore.remainingSeconds())
                                _ = scheduler.intervalAfterResume(remainingTime: remainingTime, remainingStars: remainingStars)
                                sessionStore.resume(remainingStars: remainingStars)
                            },
                            onCancel: {
                                pendingCameraMoveTask?.cancel()
                                cameraTransitionTask?.cancel()
                                if let constellationId = sessionStore.currentSession?.constellationId { placedConstellations.removeAll { $0.id == constellationId } }
                                sessionStore.cancel()
                                animateCamera(toScale: 1.0, toOffset: .zero, duration: 0.62)
                                scheduleCTA()
                            },
                            onAdvanceNextStar: {
                                let result = sessionStore.advanceToNextStar(totalStars: constellation.starCount)
                                if let completed = result.completed {
                                    pendingCameraMoveTask?.cancel()
                                    let duration = triggerSpawnEffectIfNeeded(constellation: constellation, discoveredCount: completed.discoveredStarCount)
                                    handleSessionCompleted(completed, constellation: constellation, size: size, after: duration)
                                }
                            },
                            onAdvanceFinalStar: { if sessionStore.advanceToFinalStar(totalStars: constellation.starCount) { } }
                        )
                        .padding(.horizontal, 20).padding(.bottom, 24)
                    }
                    .transition(.opacity)
                }
                
                if showCompletionOverlay {
                    VStack {
                        Spacer()
                        SessionCompletionOverlay(showRecordButton: showCompletionRecordButton, onRecord: { showMemoSheet = true })
                            .padding(.horizontal, 20).padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                if let session = selectedSession, let constellation = constellationById(session.constellationId) {
                    sessionDetailCard(session: session, constellation: constellation)
                        .padding(.horizontal, 20).padding(.top, 72).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if showDailyRewardText {
                                    VStack {
                                        Text("일일세션을 완료하여\n별 한 개를 받았어요!")
                                            .font(.headline).foregroundStyle(.black).multilineTextAlignment(.center).padding(.vertical, 16).padding(.horizontal, 32).background(Color.white, in: Capsule()).shadow(color: .white.opacity(0.3), radius: 15)
                                    }
                                    .frame(maxHeight: .infinity, alignment: .top).padding(.top, size.height * 0.2).transition(.move(edge: .top).combined(with: .opacity)).zIndex(100)
                                }
                
                if let constellation = completionConstellation {
                    CompletionAnimation(
                        constellation: constellation, reduceMotion: accessibility.isReduceMotionEnabled, highPerformanceMode: highPerformanceMode, edgeRevealOrder: completionEdgeOrder,
                        onFinished: {
                            completionConstellation = nil
                            startCompletionWrapUp(constellation: constellation, size: size)
                        }
                    ).frame(width: size.width, height: size.height).allowsHitTesting(false)
                }
                // 🔥 튜토리얼 오버레이 추가
                                if tutorialStep != .done && tutorialStep != .notStarted {
                                    TutorialOverlayView(
                                        step: $tutorialStep,
                                        onStartSession: { startTutorialWarpSession(size: size) },
                                        onTriggerReward: { triggerTutorialRewardSequence(size: size) }, // 🔥 새로 생긴 콜백
                                        onFinish: {
                                            hasSeenTutorial = true
                                            animateCamera(toScale: 1.0, toOffset: .zero, duration: 1.2) // 🔥 카메라 원래대로
                                        }
                                    )
                                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("MySky").font(.largeTitle.bold()).foregroundStyle(.white)
                }
            }
            .onAppear {
                if !hasSeenTutorial { tutorialStep = .welcome }
                else { tutorialStep = .done }
                
                showCTA = sessionStore.currentSession == nil
                hasLaidOutCTA = true
                canvasSize = size
                loadInitialPreviewConstellations()
                parseDailyStars()
            }
            .onChange(of: size) { _, newValue in canvasSize = newValue }
            .onReceive(tick) { now in syncSession(now: now) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    syncSession(now: Date())
                    scheduleCTA()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didInsertUserConstellation)) { notification in
                let extractedId: String? = (notification.object as? String) ?? (notification.object as? String?)?.flatMap { $0 }
                guard let insertedId = extractedId else { return }
                insertUserConstellationPreview(id: insertedId)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DailySessionCompleted"))) { _ in
                triggerDailyRewardSequence(size: canvasSize)
            }
            .sheet(isPresented: $showSlotPicker) { SlotPickerSheet { seconds in requestStartSession(slotSeconds: seconds) } }
            .sheet(isPresented: $showDailySessionSheet) { DailySessionView() }
            .sheet(isPresented: $showMemoSheet, onDismiss: { if pendingMemoSessionId == nil { scheduleCTA() } }) {
                MemoSheet { memo in
                    if let sessionId = pendingMemoSessionId { sessionStore.updateMemo(sessionId: sessionId, memo: memo) }
                    pendingMemoSessionId = nil; selectedSession = nil
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) { showCompletionOverlay = false; showCompletionRecordButton = false }
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    if developerMode {
                        Menu {
                            Picker("별 모양", selection: $starStyle) {
                                ForEach(StarAppearanceStyle.allCases, id: \.self) { style in Text(style.rawValue).tag(style) }
                            }
                        } label: {
                            Text("🛠 모양 변경: \(starStyle.rawValue)").font(.subheadline.bold()).foregroundStyle(.black).frame(width: 220, height: 42).background(Color.yellow.opacity(0.9), in: Capsule())
                        }.padding(.bottom, 8)
                    }
                    
                    Button { showDailySessionSheet = true } label: {
                        Text("오늘 하루 계획하기").font(.headline).foregroundStyle(.white).frame(width: 220, height: 48).background(Color.white.opacity(0.16), in: Capsule())
                    }.buttonStyle(.plain)

                    Button { showSlotPicker = true } label: {
                        Text("집중 세션 시작").font(.headline).foregroundStyle(.black).frame(width: 220, height: 48).background(Color.white, in: Capsule())
                    }.buttonStyle(.plain)
                }
                .padding(.bottom, 36)
                // 🔥 튜토리얼 중일 땐 하단 버튼들 숨김
                .opacity((showCTA && sessionStore.currentSession == nil && tutorialStep == .done) ? 1 : 0)
                .allowsHitTesting(showCTA && sessionStore.currentSession == nil && tutorialStep == .done)
                .animation(hasLaidOutCTA ? .easeInOut(duration: ctaFadeDuration) : nil, value: showCTA)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 🔥 튜토리얼 타임워프 세션 로직
    private func startTutorialWarpSession(size: CGSize) {
        Task { @MainActor in
            guard let constellation = await repository.fetchSessionConstellation(durationSeconds: 300, occupied: placedConstellations, userId: mockUserId) else { return }
            
            placedConstellations.append(constellation)
            visibleDiscoveredStarCounts[constellation.id] = 0
            edgeRevealStates[constellation.id] = EdgeRevealState()
            
            sessionStore.startSession(slotSeconds: 300, constellationId: constellation.id)
            
            // 시작 시 줌 아웃 (전체 관망)
            focusOnRepresentative(constellation, size: size, zoom: 1.0)
            
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                guard tutorialStep == .warping, sessionStore.currentStatus() == .running else {
                    timer.invalidate()
                    return
                }
                sessionStore.fastForwardTutorial(by: 6)
                syncSession(now: Date())
            }
        }
    }

    // MARK: - 🔥 보상 로직 모음 (일일 보상 + 튜토리얼 보상)
    private func parseDailyStars() {
        let pairs = dailyStarsData.split(separator: "|")
        dailyStars = pairs.compactMap { pair in
            let coords = pair.split(separator: ",")
            guard coords.count == 2, let x = Double(coords[0]), let y = Double(coords[1]) else { return nil }
            return CGPoint(x: x, y: y)
        }
    }

    private func saveDailyStar(_ point: CGPoint) {
        dailyStars.append(point)
        let pairs = dailyStars.map { "\($0.x),\($0.y)" }
        dailyStarsData = pairs.joined(separator: "|")
    }

    // 1. 일일 세션 완료용
    private func triggerDailyRewardSequence(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let newPoint = CGPoint(x: CGFloat.random(in: 0.15...0.85), y: CGFloat.random(in: 0.1...0.5))
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let wPt = worldPoint(fromNormalized: newPoint, size: size)
        let zoom: CGFloat = 1.6
        let targetOffset = CGSize(width: (center.x - wPt.x) * zoom, height: (center.y - wPt.y) * zoom)
        
        animateCamera(toScale: zoom, toOffset: targetOffset, duration: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            spawnEffectToken += 1
            dailyStarRippleCenter = newPoint
            saveDailyStar(newPoint)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showDailyRewardText = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.5)) { showDailyRewardText = false }
                dailyStarRippleCenter = nil
                animateCamera(toScale: 1.0, toOffset: .zero, duration: 1.2)
            }
        }
    }

    // 2. 튜토리얼 전용 보상 시퀀스
        private func triggerTutorialRewardSequence(size: CGSize) {
            guard size.width > 0, size.height > 0 else { return }
            let newPoint = CGPoint(x: CGFloat.random(in: 0.2...0.8), y: CGFloat.random(in: 0.2...0.4))
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let wPt = worldPoint(fromNormalized: newPoint, size: size)
            let zoom: CGFloat = 1.6
            let targetOffset = CGSize(width: (center.x - wPt.x) * zoom, height: (center.y - wPt.y) * zoom)
            
            animateCamera(toScale: zoom, toOffset: targetOffset, duration: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                spawnEffectToken += 1
                dailyStarRippleCenter = newPoint
                saveDailyStar(newPoint)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                // 🔥 별이 땅에 닿자마자 튜토리얼 말풍선을 다음 단계로 넘김!
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    tutorialStep = .dailyReward
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    dailyStarRippleCenter = nil
                    // (카메라 원상복구 로직은 onFinish 콜백으로 이동했습니다)
                }
            }
        }
    // MARK: - 기존 로직 유지
    private func constellationById(_ id: UUID) -> Constellation? { placedConstellations.first { $0.id == id } }

    private func requestStartSession(slotSeconds: Int) {
        Task { @MainActor in
            guard sessionStore.currentSession == nil else { return }
            let normalizedSeconds = max(30 * 60, slotSeconds)
            let fullOccupied = placedConstellations + previewConstellations
            var constellation = await repository.fetchSessionConstellation(durationSeconds: normalizedSeconds, occupied: fullOccupied, userId: mockUserId)

            if constellation == nil, !previewConstellations.isEmpty {
                constellation = await repository.fetchSessionConstellation(durationSeconds: normalizedSeconds, occupied: placedConstellations, userId: mockUserId)
            }

            guard let constellation else { return }
            prunePreviewConstellations(conflictingWith: constellation)
            placedConstellations.append(constellation)
            pendingCameraMoveTask?.cancel()
            completionFlowTask?.cancel()
            showCompletionOverlay = false
            showCompletionRecordButton = false
            pendingMemoSessionId = nil
            visibleDiscoveredStarCounts[constellation.id] = 0
            edgeRevealStates[constellation.id] = EdgeRevealState()
            sessionStore.startSession(slotSeconds: normalizedSeconds, constellationId: constellation.id)
            selectedSession = nil
            showCTA = false
            focusNextStarIfNeeded(constellation: constellation, size: canvasSize)
        }
    }

    private func syncSession(now: Date) {
        guard let session = sessionStore.currentSession, let constellation = constellationById(session.constellationId) else { return }

        let result = sessionStore.refreshCurrentSession(now: now, totalStars: constellation.starCount, scheduler: scheduler)
        if result.newlyDiscovered && result.completed == nil {
            let discoveredCount = sessionStore.currentSession?.discoveredStarCount ?? session.discoveredStarCount
            let duration = triggerSpawnEffectIfNeeded(constellation: constellation, discoveredCount: discoveredCount)
            scheduleVisibleEdgeReveal(constellationId: constellation.id, discoveredCount: discoveredCount, after: duration)
            beginEdgeRevealAnimation(constellation: constellation, discoveredCount: discoveredCount, duration: duration)
            scheduleMoveToNextStarAfterSpawn(constellation: constellation, after: duration)
        }
        if let completed = result.completed {
            pendingCameraMoveTask?.cancel()
            let duration = triggerSpawnEffectIfNeeded(constellation: constellation, discoveredCount: completed.discoveredStarCount)
            scheduleVisibleEdgeReveal(constellationId: constellation.id, discoveredCount: completed.discoveredStarCount, after: duration)
            beginEdgeRevealAnimation(constellation: constellation, discoveredCount: completed.discoveredStarCount, duration: duration)
            handleSessionCompleted(completed, constellation: constellation, size: canvasSize, after: duration)
        }
    }

    private func handleSessionCompleted(_ completed: FocusSession, constellation: Constellation, size: CGSize, after delay: TimeInterval = 0) {
        pendingMemoSessionId = completed.id
        selectedSession = nil

        if completionEffectEnabled {
            completionConstellation = constellation
            completionEdgeOrder = bfsEdgeOrder(constellation: constellation)
        } else {
            completionConstellation = nil
            completionEdgeOrder = []
            startCompletionWrapUp(constellation: constellation, size: size, afterEffectDelay: delay)
        }
    }

    private func startCompletionWrapUp(constellation: Constellation, size: CGSize, afterEffectDelay delay: TimeInterval = 0) {
            completionFlowTask?.cancel()
            completionFlowTask = Task { @MainActor in
                if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                guard !Task.isCancelled else { return }
                focusOnRepresentative(constellation, size: size, zoom: sessionAutoZoom)
                try? await Task.sleep(for: .seconds(completionCameraMoveDuration))
                guard !Task.isCancelled else { return }
                
                // 🔥 튜토리얼 모드일 경우 정상적인 완료 오버레이를 띄우지 않고 튜토리얼 5단계로 스킵!
                if tutorialStep == .warping {
                    // ⭐️ 핵심 해결: 튜토리얼 중엔 메모 대기를 강제로 해제하여 화면 잠금을 풉니다!
                    pendingMemoSessionId = nil
                    withAnimation { tutorialStep = .constellationDone }
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                        showCompletionOverlay = true
                        showCompletionRecordButton = false
                    }
                    try? await Task.sleep(for: .seconds(0.55))
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.46, dampingFraction: 0.88)) {
                        showCompletionRecordButton = true
                    }
                }
            }
        }
    
    private func registerInteraction() {
        if showCTA { withAnimation(.easeInOut(duration: ctaFadeDuration)) { showCTA = false } }
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
            withAnimation(.easeInOut(duration: ctaFadeDuration)) { showCTA = true }
        }
    }

    private func dragGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                registerInteraction()
                offset = CGSize(width: offset.width + value.translation.width - lastDrag.width, height: offset.height + value.translation.height - lastDrag.height)
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
                            if let best, best.distance <= distance { continue }
                            best = (session, distance)
                        }
                    }
                }
                withAnimation(.easeInOut(duration: 0.2)) { selectedSession = best?.session }
            }
    }

    private func normalizeTap(_ location: CGPoint, size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let world = CGPoint(
            x: ((location.x - offset.width - center.x) / scale) + center.x,
            y: ((location.y - offset.height - center.y) / scale) + center.y
        )
        return normalizedFromWorldPoint(world, size: size)
    }

    @ViewBuilder
    private func interactiveSkyLayer(size: CGSize) -> some View {
        let base = ZStack {
            ambientStarLayer(size: size)
            skyCanvas(size: size)
        }
        .scaleEffect(scale)
        .offset(offset)
        .animation(nil, value: scale)
        .animation(nil, value: offset)
        .contentShape(Rectangle())

        if isSkyInteractionLocked {
            base.allowsHitTesting(false)
        } else if sessionStore.currentSession == nil {
            base
                .gesture(dragGesture())
                .simultaneousGesture(magnificationGesture())
                .simultaneousGesture(tapGesture(size: size))
        } else {
            base
        }
    }

    private func focusNextStarIfNeeded(constellation: Constellation, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        // 🔥 핵심 수정: 워프 중일 때는 카메라가 별을 하나하나 따라가지 않게 끕니다!
        guard tutorialStep != .warping else { return }
        
        guard let session = sessionStore.currentSession else { return }
        let nextIndex = min(session.discoveredStarCount, constellation.starCount - 1)
        guard constellation.stars.indices.contains(nextIndex) else { return }
        focusOnStar(constellation.stars[nextIndex], size: size, zoom: sessionAutoZoom)
    }

    private func focusOnRepresentative(_ constellation: Constellation, size: CGSize, zoom: CGFloat) {
        guard size.width > 0, size.height > 0 else { return }
        let star = Star(x: constellation.representativePoint.x, y: constellation.representativePoint.y)
        focusOnStar(star, size: size, zoom: zoom)
    }

    private func focusOnStar(_ star: Star, size: CGSize, zoom: CGFloat) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let point = worldPoint(fromNormalized: CGPoint(x: star.x, y: star.y), size: size)
        let nextOffset = CGSize(width: (center.x - point.x) * zoom, height: (center.y - point.y) * zoom)
        animateCamera(toScale: zoom, toOffset: nextOffset, duration: 1.05)
    }

    private func animateCamera(toScale targetScale: CGFloat, toOffset targetOffset: CGSize, duration: TimeInterval) {
        cameraTransitionTask?.cancel()
        let startScale = scale
        let startOffset = offset
        let frameCount = max(12, Int(duration * 60))

        cameraTransitionTask = Task { @MainActor in
            for step in 1...frameCount {
                guard !Task.isCancelled else { return }
                let t = CGFloat(step) / CGFloat(frameCount)
                let eased = t * t * (3 - 2 * t)
                scale = startScale + (targetScale - startScale) * eased
                scaleAnchor = scale
                offset = CGSize(
                    width: startOffset.width + (targetOffset.width - startOffset.width) * eased,
                    height: startOffset.height + (targetOffset.height - startOffset.height) * eased
                )
                try? await Task.sleep(for: .seconds(duration / Double(frameCount)))
            }
            scale = targetScale
            scaleAnchor = targetScale
            offset = targetOffset
        }
    }

    @discardableResult
    private func triggerSpawnEffectIfNeeded(constellation: Constellation, discoveredCount: Int) -> TimeInterval {
        let newIndex = discoveredCount - 1
        guard newIndex >= 0, constellation.stars.indices.contains(newIndex) else { return 0 }
        let star = constellation.stars[newIndex]
        starBirthCenter = CGPoint(x: star.x, y: star.y)
        starBirthSegments = birthConnectionSegments(constellation: constellation, discoveredCount: discoveredCount, newStarId: star.id)
        spawnEffectToken += 1
        let effectDuration: TimeInterval = accessibility.isReduceMotionEnabled ? 0.42 : 1.5

        Task { @MainActor in
            let token = spawnEffectToken
            try? await Task.sleep(for: .seconds(effectDuration))
            guard spawnEffectToken == token else { return }
            starBirthCenter = nil
            starBirthSegments = []
        }
        return effectDuration
    }

    private func birthConnectionSegments(constellation: Constellation, discoveredCount: Int, newStarId: UUID) -> [StarBirthSegment] {
        let discoveredIds = Set(constellation.stars.prefix(discoveredCount).map(\.id))
        let byId = Dictionary(uniqueKeysWithValues: constellation.stars.map { ($0.id, $0) })
        return constellation.edges.compactMap { edge in
            let isConnectedToNew = edge.from == newStarId || edge.to == newStarId
            guard isConnectedToNew, discoveredIds.contains(edge.from), discoveredIds.contains(edge.to) else { return nil }
            guard let from = byId[edge.from], let to = byId[edge.to] else { return nil }
            return StarBirthSegment(from: CGPoint(x: from.x, y: from.y), to: CGPoint(x: to.x, y: to.y))
        }
    }

    private func runningEdgeIndices(constellation: Constellation, discoveredCount: Int) -> Set<Int> {
        guard discoveredCount > 0 else { return [] }
        let discoveredIds = Set(constellation.stars.prefix(discoveredCount).map(\.id))
        var indices: Set<Int> = []
        for (index, edge) in constellation.edges.enumerated() {
            if discoveredIds.contains(edge.from), discoveredIds.contains(edge.to) { indices.insert(index) }
        }
        return indices
    }

    private func scheduleVisibleEdgeReveal(constellationId: UUID, discoveredCount: Int, after delay: TimeInterval) {
        Task { @MainActor in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            visibleDiscoveredStarCounts[constellationId] = discoveredCount
        }
    }

    private func beginEdgeRevealAnimation(constellation: Constellation, discoveredCount: Int, duration: TimeInterval) {
        let id = constellation.id
        var state = edgeRevealStates[id] ?? EdgeRevealState()
        state.pendingDiscoveredCount = discoveredCount
        state.progress = duration > 0 ? 0 : 1
        edgeRevealStates[id] = state

        let token = (edgeRevealTokens[id] ?? 0) + 1
        edgeRevealTokens[id] = token

        if duration > 0 { withAnimation(.linear(duration: duration)) { edgeRevealStates[id]?.progress = 1 } }

        Task { @MainActor in
            if duration > 0 { try? await Task.sleep(for: .seconds(duration)) }
            guard edgeRevealTokens[id] == token else { return }
            guard var latest = edgeRevealStates[id] else { return }
            latest.committedDiscoveredCount = discoveredCount
            latest.pendingDiscoveredCount = nil
            latest.progress = 0
            edgeRevealStates[id] = latest
        }
    }

    private func edgeRenderState(for constellation: Constellation) -> (visibleIndices: Set<Int>, visibilityOverrides: [Int: CGFloat]) {
        let state = edgeRevealStates[constellation.id] ?? EdgeRevealState()
        let committedIndices = runningEdgeIndices(constellation: constellation, discoveredCount: state.committedDiscoveredCount)
        guard let pendingCount = state.pendingDiscoveredCount else { return (committedIndices, [:]) }

        let pendingIndices = runningEdgeIndices(constellation: constellation, discoveredCount: pendingCount).subtracting(committedIndices)
        var visibilityOverrides = Dictionary(uniqueKeysWithValues: committedIndices.map { ($0, CGFloat(1)) })
        for index in pendingIndices { visibilityOverrides[index] = state.progress }
        return (committedIndices.union(pendingIndices), visibilityOverrides)
    }

    private func scheduleMoveToNextStarAfterSpawn(constellation: Constellation, after delay: TimeInterval) {
        pendingCameraMoveTask?.cancel()
        pendingCameraMoveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(0, delay)))
            guard !Task.isCancelled, sessionStore.currentSession != nil, sessionStore.currentStatus() == .running else { return }
            focusNextStarIfNeeded(constellation: constellation, size: canvasSize)
        }
    }

    private func screenPoint(normalized: CGPoint, size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let world = worldPoint(fromNormalized: normalized, size: size)
        let translated = CGPoint(x: world.x - center.x, y: world.y - center.y)
        return CGPoint(x: translated.x * scale + center.x + offset.width, y: translated.y * scale + center.y + offset.height)
    }

    private func worldPoint(fromNormalized point: CGPoint, size: CGSize) -> CGPoint {
        let side = min(size.width, size.height)
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        return CGPoint(x: origin.x + point.x * side, y: origin.y + point.y * side)
    }

    private func normalizedFromWorldPoint(_ world: CGPoint, size: CGSize) -> CGPoint {
        let side = max(1, min(size.width, size.height))
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        let nx = (world.x - origin.x) / side
        let ny = (world.y - origin.y) / side
        return CGPoint(x: nx, y: ny)
    }

    private func bfsEdgeOrder(constellation: Constellation) -> [Int] {
        guard !constellation.stars.isEmpty, !constellation.edges.isEmpty else { return [] }
        let idToIndex = Dictionary(uniqueKeysWithValues: constellation.stars.enumerated().map { ($0.element.id, $0.offset) })
        var adjacency: [UUID: [(neighbor: UUID, edgeIndex: Int)]] = [:]

        for (edgeIndex, edge) in constellation.edges.enumerated() {
            adjacency[edge.from, default: []].append((edge.to, edgeIndex))
            adjacency[edge.to, default: []].append((edge.from, edgeIndex))
        }

        let startId = constellation.stars[0].id
        var queue: [UUID] = [startId]
        var visited: Set<UUID> = [startId]
        var usedEdges: Set<Int> = []
        var order: [Int] = []

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let neighbors = adjacency[current, default: []].sorted { (idToIndex[$0.neighbor] ?? .max) < (idToIndex[$1.neighbor] ?? .max) }
            for entry in neighbors where !usedEdges.contains(entry.edgeIndex) {
                usedEdges.insert(entry.edgeIndex)
                order.append(entry.edgeIndex)
                if !visited.contains(entry.neighbor) {
                    visited.insert(entry.neighbor)
                    queue.append(entry.neighbor)
                }
            }
        }
        if order.count < constellation.edges.count {
            for edgeIndex in constellation.edges.indices where !usedEdges.contains(edgeIndex) { order.append(edgeIndex) }
        }
        return order
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
                        Circle().fill(star.color.opacity(opacity)).frame(width: star.size, height: star.size)
                        if shouldAnimate && star.hasFlare {
                            AmbientStarFlare(length: star.size * (2.4 + CGFloat(pulse)), thickness: max(0.3, star.size * 0.12), color: star.color.opacity(opacity * 0.4))
                                .rotationEffect(.degrees(star.flareAngle))
                        }
                    }.shadow(color: star.color.opacity(0.5), radius: glow).position(x: star.x * size.width, y: star.y * size.height)
                }
            }
        }.allowsHitTesting(false)
    }

    @ViewBuilder
    private func skyCanvas(size: CGSize) -> some View {
        let completionConstellationId = completionConstellation?.id
        let activeConstellationIds = Set(sessionStore.completedSessions.map(\.constellationId) + [sessionStore.currentSession?.constellationId].compactMap { $0 })

        ZStack {
            ForEach(Array(dailyStars.enumerated()), id: \.offset) { index, pt in
                let wPt = worldPoint(fromNormalized: pt, size: size)
                DailyRewardStarNode(position: wPt)
            }

            ForEach(previewConstellations) { constellation in
                if !activeConstellationIds.contains(constellation.id) {
                    ConstellationRenderer(constellation: constellation, discoveredStarCount: constellation.starCount, showEdges: true, edgeProgress: 1, reduceMotion: accessibility.isReduceMotionEnabled, highPerformanceMode: highPerformanceMode, starStyle: starStyle).opacity(0.5)
                }
            }

            ForEach(sessionStore.completedSessions) { session in
                if completionConstellationId != session.constellationId, let constellation = constellationById(session.constellationId) {
                    let visibleCount = visibleDiscoveredStarCounts[session.constellationId] ?? constellation.starCount
                    let edgeState = edgeRenderState(for: constellation)
                    ConstellationRenderer(constellation: constellation, discoveredStarCount: visibleCount, showEdges: true, edgeProgress: 1, reduceMotion: accessibility.isReduceMotionEnabled, highPerformanceMode: highPerformanceMode, visibleEdgeIndices: edgeState.visibleIndices, edgeVisibilityOverrides: edgeState.visibilityOverrides, starStyle: starStyle)
                }
            }

            if let running = sessionStore.currentSession, let constellation = constellationById(running.constellationId) {
                let edgeState = edgeRenderState(for: constellation)
                ConstellationRenderer(constellation: constellation, discoveredStarCount: running.discoveredStarCount, showEdges: true, edgeProgress: 1, reduceMotion: accessibility.isReduceMotionEnabled, highPerformanceMode: highPerformanceMode, visibleEdgeIndices: edgeState.visibleIndices, edgeVisibilityOverrides: edgeState.visibilityOverrides, starStyle: starStyle)
            }
        }.frame(width: size.width, height: size.height)
    }

    private func loadInitialPreviewConstellations() {
        Task { @MainActor in
            guard previewConstellations.isEmpty else { return }
            previewConstellations = await repository.fetchInitialPreviewConstellations(occupied: placedConstellations, limit: 3)
        }
    }

    private func insertUserConstellationPreview(id: String) {
        Task { @MainActor in
            let occupied = placedConstellations + previewConstellations
            if let constellation = await repository.fetchInsertedUserConstellation(id: id, userId: mockUserId, occupied: occupied) {
                if !previewConstellations.contains(where: { $0.id == constellation.id }) { previewConstellations.insert(constellation, at: 0) }
            } else {
                if let forcedConstellation = await repository.fetchInsertedUserConstellation(id: id, userId: mockUserId, occupied: placedConstellations) {
                    previewConstellations.removeAll()
                    previewConstellations.append(forcedConstellation)
                }
            }
        }
    }

    private func prunePreviewConstellations(conflictingWith constellation: Constellation) {
        previewConstellations.removeAll { preview in
            guard preview.id != constellation.id else { return true }
            return constellationsLikelyOverlap(preview, constellation)
        }
    }

    private func constellationsLikelyOverlap(_ lhs: Constellation, _ rhs: Constellation) -> Bool {
        let lhsRadius = constellationRadius(lhs)
        let rhsRadius = constellationRadius(rhs)
        let dx = lhs.representativePoint.x - rhs.representativePoint.x
        let dy = lhs.representativePoint.y - rhs.representativePoint.y
        return hypot(dx, dy) < (lhsRadius + rhsRadius + 0.02)
    }

    private func constellationRadius(_ constellation: Constellation) -> CGFloat {
        let rep = constellation.representativePoint
        return (constellation.stars.map { hypot($0.x - rep.x, $0.y - rep.y) }.max() ?? 0) + 0.035
    }

    @ViewBuilder
    private func sessionDetailCard(session: FocusSession, constellation: Constellation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(constellation.name).font(.headline); Spacer(); Text("by Focustella").font(.caption).foregroundStyle(.secondary) }
            if let endedAt = session.endedAt { Text("완료: \(endedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
            if let memo = session.memo {
                Text("태그: \(memo.topicTags.joined(separator: ", "))").font(.caption)
                Text("성취도: \(String(repeating: "★", count: memo.rating))").font(.caption)
                if let text = memo.freeText, !text.isEmpty { Text(text).font(.caption).foregroundStyle(.secondary) }
            } else { Text("메모 없음").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(14).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { selectedSession = nil } }
    }
}

// MARK: - 일일 보상용 황금 별 디자인, Shape, 파동 애니메이션 유지
private struct DailyRewardStarNode: View {
    let position: CGPoint
    @State private var isBlinking = false
    var body: some View {
        let size: CGFloat = 16
        let color = Color(red: 1.0, green: 0.9, blue: 0.6)
        ZStack {
            Circle().fill(color.opacity(0.3)).frame(width: size * 2.5, height: size * 2.5).blur(radius: size * 0.4).opacity(isBlinking ? 1.0 : 0.5)
            RewardStarShape(innerRatio: 0.35).fill(RadialGradient(colors: [.white, color], center: .center, startRadius: 0, endRadius: size / 2)).frame(width: size, height: size)
        }.position(position).onAppear { withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { isBlinking = true } }
    }
}

private struct RewardStarShape: Shape {
    var innerRatio: CGFloat
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let w = rect.width / 2, h = rect.height / 2
        let ix = w * innerRatio, iy = h * innerRatio
        var p = Path()
        p.move(to: CGPoint(x: center.x, y: center.y - h))
        p.addQuadCurve(to: CGPoint(x: center.x + w, y: center.y), control: CGPoint(x: center.x + ix, y: center.y - iy))
        p.addQuadCurve(to: CGPoint(x: center.x, y: center.y + h), control: CGPoint(x: center.x + ix, y: center.y + iy))
        p.addQuadCurve(to: CGPoint(x: center.x - w, y: center.y), control: CGPoint(x: center.x - ix, y: center.y + iy))
        p.addQuadCurve(to: CGPoint(x: center.x, y: center.y - h), control: CGPoint(x: center.x - ix, y: center.y - iy))
        return p
    }
}

private struct RippleEffectView: View {
    let position: CGPoint
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0.0
    private let coreColor = Color(white: 0.95)
    private let glowColor = Color(red: 0.78, green: 0.92, blue: 1.0)
    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle().stroke(coreColor.opacity(0.7 * (1 - progress)), lineWidth: 15 * (1 - progress * 0.5)).frame(width: 20 + (progress * 100), height: 20 + (progress * 100)).blur(radius: 10).padding(20)
                Circle().stroke(glowColor.opacity(0.5 * (1 - progress)), lineWidth: 25 * (1 - progress * 0.5)).frame(width: 10 + (progress * 140), height: 10 + (progress * 140)).blur(radius: 20).padding(30)
                Circle().stroke(glowColor.opacity(0.3 * (1 - progress)), lineWidth: 40 * (1 - progress * 0.8)).frame(width: 5 + (progress * 180), height: 5 + (progress * 180)).blur(radius: 40).padding(50)
            }
        }.frame(width: 300, height: 300).position(position).onAppear { withAnimation(.easeOut(duration: 2.0)) { progress = 1.0 } }
    }
}
