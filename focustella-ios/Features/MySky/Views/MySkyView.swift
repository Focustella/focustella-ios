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
    @StateObject private var viewModel = MySkyViewModel()
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var accessibility = AppAccessibility.shared
    @AppStorage("highPerformanceMode") private var highPerformanceMode: Bool = false
    @AppStorage("developerMode") private var developerMode: Bool = false
    @AppStorage("starStyle") private var starStyle: StarAppearanceStyle = .realistic
    @AppStorage("mySkyBackgroundVariant") private var backgroundVariant: MySkyBackgroundVariant = .focusStar
    @AppStorage("userId") private var userId: String = ""
    @AppStorage("userSeed") private var userSeed: Int = 0
    
    // 🔥 튜토리얼 진행 상태 저장
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    @State private var tutorialStep: TutorialStep = .notStarted
    
    @AppStorage("dailyStarsData") private var dailyStarsData: String = ""
    @State private var dailyStars: [DailyStarItem] = []
    @State private var selectedDailyStar: DailyStarItem? // 터치된 별을 기억할 변수
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
    @State private var activeStarBirthEffect: StarBirthEffectState?
    @State private var spawnEffectToken: Int = 0
    @State private var pendingCameraMoveTask: Task<Void, Never>?
    @State private var cameraTransitionTask: Task<Void, Never>?
    @State private var showCompletionOverlay = false
    @State private var showCompletionRecordButton = false
    @State private var completionFlowTask: Task<Void, Never>?
    @State private var completionEdgeOrder: [Int] = []
    @State private var hasLaidOutCTA = false
    @State private var hasInitializedView = false
    @State private var remoteFocusLayoutItems: [FocusSkyLayoutItem] = []
    @State private var placedConstellations: [Constellation] = []
    @State private var visibleDiscoveredStarCounts: [UUID: Int] = [:]
    @State private var edgeRevealStates: [UUID: EdgeRevealState] = [:]
    @State private var edgeRevealTokens: [UUID: Int] = [:]
    @State private var isFetchingSky = false
    
    private let ctaFadeDuration: Double = 0.38
    private let ctaIdleDelay: Double = 1.5
    private let sessionAutoZoom: CGFloat = 2.0
    private let completionEffectEnabled = false
    private let completionCameraMoveDuration: TimeInterval = 1.05

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let fallbackLocalUserId = "local-user"

    private var isSkyInteractionLocked: Bool {
        pendingMemoSessionId != nil || showMemoSheet || tutorialStep != .done
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let ctaBottomInset = max(36, proxy.safeAreaInsets.bottom + 94)
            
            ZStack {
                MySkyBackgroundLayer(
                    canvasSize: size,
                    safeAreaInsets: proxy.safeAreaInsets,
                    scale: scale,
                    offset: offset,
                    variant: backgroundVariant
                )
                interactiveSkyLayer(size: size)
                
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
                                if let serverSessionId = sessionStore.currentSession?.serverSessionId {
                                    remoteFocusLayoutItems.removeAll { $0.sessionId == serverSessionId }
                                    rebuildRemoteFocusLayout()
                                } else if let constellationId = sessionStore.currentSession?.constellationId {
                                    placedConstellations.removeAll { $0.id == constellationId }
                                }
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
                                                onSaveNickname: { newNickname in
                                                    // 🔥 여기서 뷰모델의 통신 함수를 호출합니다!
                                                    return await viewModel.saveNickname(newNickname)
                                                },
                                        onStartSession: { startTutorialWarpSession(size: size) },
                                        onOpenDailySession: { showDailySessionSheet = true },
                                        onTriggerReward: { triggerTutorialRewardSequence(size: size) }, // 🔥 새로 생긴 콜백
                                        onFinish: {
                                            hasSeenTutorial = true
                                            animateCamera(toScale: 1.0, toOffset: .zero, duration: 1.2) // 🔥 카메라 원래대로
                                        }
                                    )
                                }
            }
            .overlay(alignment: .topTrailing) {
                            if developerMode {
                                Menu {
                                    Picker("별 모양", selection: $starStyle) {
                                        ForEach(StarAppearanceStyle.allCases, id: \.self) { style in
                                            Text(style.rawValue).tag(style)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "wrench.and.screwdriver.fill")
                                            .font(.system(size: 12))
                                        Text(starStyle.rawValue)
                                            .font(.caption.bold())
                                    }
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.yellow.opacity(0.9), in: Capsule())
                                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                                }
                                // 안전 영역(노치/다이내믹 아일랜드) 아래로 충분히 내리고 우측 여백 주기
                                .padding(.top, proxy.safeAreaInsets.top + 56)
                                .padding(.trailing, 20)
                            }
                        }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("MySky").font(.largeTitle.bold()).foregroundStyle(.white)
                }
            }
            .onAppear {
                            canvasSize = size
                            guard !hasInitializedView else { return }

                            hasInitializedView = true
                            
                            // 🔥 수정: 튜토리얼의 첫 시작점을 닉네임 묻기로 변경합니다!
                            if !hasSeenTutorial { tutorialStep = .askNickname }
                            else { tutorialStep = .done }

                            showCTA = sessionStore.currentSession == nil
                            hasLaidOutCTA = true
                            parseDailyStars()

                            // Keep the first sky fetch on initial mount only so tab switches do not
                            // recreate the whole sky state and trigger another expensive re-render.
                            Task {
                                await refreshSky()
                                await syncLocalInsertedConstellations()
                            }
                        }
            .onChange(of: size) { _, newValue in canvasSize = newValue }
            .onReceive(tick) { now in syncSession(now: now) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    syncSession(now: Date())
                    scheduleCTA()
                    Task { await syncLocalInsertedConstellations() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didInsertUserConstellation)) { notification in
                let extractedId: String? = (notification.object as? String) ?? (notification.object as? String?)?.flatMap { $0 }
                guard let insertedId = extractedId else { return }
                Self.logger.notice("received dev constellation notification id=\(insertedId, privacy: .public)")
                insertUserConstellationAsCompleted(id: insertedId)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DailySessionCompleted"))) { _ in
                if !hasSeenTutorial && tutorialStep == .waitDaily {
                                    // 튜토리얼 중 일일 세션을 완료했다면!
                                    tutorialStep = .spawningReward
                                    triggerTutorialRewardSequence(size: canvasSize)
                                } else {
                                    // 평소의 일반 일일 세션 보상
                                    triggerDailyRewardSequence(size: canvasSize)
                                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowFocusSession"))) { _ in showSlotPicker = true }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowDailySession"))) { _ in showDailySessionSheet = true }
            .sheet(isPresented: $showSlotPicker) { SlotPickerSheet { seconds in requestStartSession(slotSeconds: seconds) } }
            .sheet(isPresented: $showDailySessionSheet) {
                            DailySessionView() 
                        }
                        // 🔥 튜토리얼 강제 종료(탈옥) 방지 로직 추가!
                        .onChange(of: showDailySessionSheet) { _, isShowing in
                            // 시트가 방금 닫혔고(!isShowing),
                            // 튜토리얼을 아직 안 봤고(!hasSeenTutorial),
                            // 현재 상태가 일일 세션 대기 중(.waitDaily)이라면
                            // = 완료 버튼을 안 누르고 강제로 바깥쪽을 터치해서 닫은 상황!
                            if !isShowing && !hasSeenTutorial && tutorialStep == .waitDaily {
                                
                                print("🚨 튜토리얼 이탈 감지! 이전 단계로 롤백합니다.")
                                
                                // 다시 "일일 세션 계획하기" 툴팁과 버튼이 보이도록 살짝 돌려놓습니다.
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    tutorialStep = .suggestDaily
                                }
                            }
                        }
                        .sheet(isPresented: $showMemoSheet, onDismiss: { if pendingMemoSessionId == nil { scheduleCTA() } }) {
                            MemoSheet { memo in
                                let didSave = await saveCompletedSessionMemo(memo)
                                if didSave {
                                    pendingMemoSessionId = nil
                                    selectedSession = nil
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                                        showCompletionOverlay = false
                                        showCompletionRecordButton = false
                                    }
                                }
                                return didSave
                            }
                        }
            // 🔥 여기서부터 다시 추가! (우주 화면 하단에 떠 있는 시작 버튼들)
                        .overlay(alignment: .bottom) {
                            VStack(spacing: 10) {
                                Button {
                                    showDailySessionSheet = true
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
                            .padding(.bottom, ctaBottomInset)
                            // 튜토리얼이 끝났고, 현재 진행 중인 세션이 없을 때만 보임
                            .opacity((showCTA && sessionStore.currentSession == nil && tutorialStep == .done) ? 1 : 0)
                            .allowsHitTesting(showCTA && sessionStore.currentSession == nil && tutorialStep == .done)
                            .animation(hasLaidOutCTA ? .easeInOut(duration: ctaFadeDuration) : nil, value: showCTA)
                        }
                    } // ZStack 닫기
                    .preferredColorScheme(.dark)
                }

    // MARK: - 🔥 튜토리얼 타임워프 세션 로직
    private func startTutorialWarpSession(size: CGSize) {
        Task { @MainActor in
            guard let constellation = await repository.fetchSessionConstellation(
                durationSeconds: 300,
                occupied: placedConstellations,
                userId: localConstellationUserId,
                randomSeed: Int64(userSeed)
            ) else { return }
            
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

    // 🔥 2. 로컬 캐시 파싱 로직 업데이트 (x, y, timestamp 형태로 저장/불러오기)
        private func parseDailyStars() {
            let pairs = dailyStarsData.split(separator: "|")
            dailyStars = pairs.compactMap { pair in
                let components = pair.split(separator: ",")
                guard components.count == 3,
                      let x = Double(components[0]),
                      let y = Double(components[1]),
                      let timestamp = TimeInterval(components[2]) else { return nil }
                return DailyStarItem(position: CGPoint(x: x, y: y), date: Date(timeIntervalSince1970: timestamp))
            }
        }
    
    private func saveDailyStar(_ point: CGPoint) {
            let newItem = DailyStarItem(position: point, date: Date())
            dailyStars.append(newItem)
            
            // "x,y,시간|x,y,시간" 형태로 저장
            let pairs = dailyStars.map { "\($0.position.x),\($0.position.y),\($0.date.timeIntervalSince1970)" }
            dailyStarsData = pairs.joined(separator: "|")
        }
    // 1. 일일 세션 완료용
    private func triggerDailyRewardSequence(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let newPoint = CGPoint(x: CGFloat.random(in: 0.15...0.85), y: CGFloat.random(in: 0.1...0.5))
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let wPt = coordinateMapper(for: size).worldPoint(fromNormalized: newPoint)
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
            let wPt = coordinateMapper(for: size).worldPoint(fromNormalized: newPoint)
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
            do {
                let created = try await viewModel.createFocusSession(durationMinutes: normalizedSeconds / 60)
                let startedAt = Date()
                let createdItem = viewModel.makeCreatedFocusLayoutItem(
                    created,
                    startedAt: startedAt,
                    slotSeconds: normalizedSeconds
                )
                remoteFocusLayoutItems.append(createdItem)

                let layout = viewModel.layoutFocusConstellations(remoteFocusLayoutItems, userSeed: Int64(userSeed))
                guard let createdResult = layout.first(where: { $0.item.sessionId == created.focusSessionId }) else {
                    remoteFocusLayoutItems.removeAll { $0.sessionId == created.focusSessionId }
                    Self.logger.error("focus create placement failed for sessionId=\(created.focusSessionId)")
                    return
                }

                let constellation = createdResult.constellation
                guard !constellation.stars.isEmpty else {
                    remoteFocusLayoutItems.removeAll { $0.sessionId == created.focusSessionId }
                    return
                }

                applyRemoteFocusLayout(layout)
                pendingCameraMoveTask?.cancel()
                completionFlowTask?.cancel()
                showCompletionOverlay = false
                showCompletionRecordButton = false
                pendingMemoSessionId = nil
                visibleDiscoveredStarCounts[constellation.id] = 0
                edgeRevealStates[constellation.id] = EdgeRevealState()
                sessionStore.startSession(
                    slotSeconds: normalizedSeconds,
                    constellationId: constellation.id,
                    serverSessionId: created.focusSessionId,
                    serverConstellationId: created.constellationId,
                    now: startedAt
                )
                selectedSession = nil
                showCTA = false
                focusNextStarIfNeeded(constellation: constellation, size: canvasSize)
            } catch {
                Self.logger.error("focus create failed: \(error.localizedDescription)")
            }
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedSession = best?.session
                    selectedDailyStar = nil // 🌟 빈 우주를 터치하면 황금별 말풍선도 닫히도록 추가!
                }
            }
    }

    private func normalizeTap(_ location: CGPoint, size: CGSize) -> CGPoint {
        let mapper = coordinateMapper(for: size)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let world = CGPoint(
            x: ((location.x - offset.width - center.x) / scale) + center.x,
            y: ((location.y - offset.height - center.y) / scale) + center.y
        )
        return mapper.normalizedPoint(fromWorld: world)
    }

    @ViewBuilder
    private func interactiveSkyLayer(size: CGSize) -> some View {
        let base = skyCanvas(size: size)
            .overlay {
                // Keep the effect layer inside the exact same viewport bounds as the
                // constellation canvas so zoom/pan transforms use an identical center.
                interactiveEffectLayer(size: size)
                    .frame(width: size.width, height: size.height)
            }
            .frame(width: size.width, height: size.height)
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
        let point = coordinateMapper(for: size).worldPoint(for: star)
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
        spawnEffectToken += 1
        activeStarBirthEffect = StarBirthEffectState(
            constellationId: constellation.id,
            starId: star.id,
            connectionPairs: birthConnectionPairs(constellation: constellation, discoveredCount: discoveredCount, newStarId: star.id),
            token: spawnEffectToken
        )
        let effectDuration: TimeInterval = accessibility.isReduceMotionEnabled ? 0.42 : 1.5

        Task { @MainActor in
            let token = spawnEffectToken
            try? await Task.sleep(for: .seconds(effectDuration))
            guard spawnEffectToken == token else { return }
            activeStarBirthEffect = nil
        }
        return effectDuration
    }

    private func birthConnectionPairs(constellation: Constellation, discoveredCount: Int, newStarId: UUID) -> [StarBirthConnectionPair] {
        let discoveredIds = Set(constellation.stars.prefix(discoveredCount).map(\.id))
        return constellation.edges.compactMap { edge in
            let isConnectedToNew = edge.from == newStarId || edge.to == newStarId
            guard isConnectedToNew, discoveredIds.contains(edge.from), discoveredIds.contains(edge.to) else { return nil }
            return StarBirthConnectionPair(fromStarId: edge.from, toStarId: edge.to)
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

    private func coordinateMapper(for size: CGSize) -> MySkyCoordinateMapper {
        MySkyCoordinateMapper(canvasSize: size)
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
        private func skyCanvas(size: CGSize) -> some View {
            let mapper = coordinateMapper(for: size)
            let completionConstellationId = completionConstellation?.id
            ZStack {
                        // 🔥 3. 황금 별 렌더링 및 터치 이벤트
                        ForEach(dailyStars) { item in
                            let wPt = mapper.worldPoint(fromNormalized: item.position)
                            
                            DailyRewardStarNode() // (좌표 파라미터 삭제)
                                .frame(width: 40, height: 40) // 알맹이 겉에 40x40짜리 터치 박스를 씌움
                                .contentShape(Circle())       // 박스 모양은 동그라미!
                                .onTapGesture {               // 터치 이벤트 달기
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        if selectedDailyStar?.id == item.id {
                                            selectedDailyStar = nil
                                        } else {
                                            selectedDailyStar = item
                                        }
                                    }
                                }
                                .position(wPt)
                    // 🔥 4. 선택된 별 위에 뜨는 날짜 말풍선!
                    if selectedDailyStar?.id == item.id {
                        VStack(spacing: 4) {
                            Text("✨ 일일 세션 완료")
                                .font(.caption2.bold())
                                .foregroundStyle(.yellow)
                            Text(item.date.formatted(date: .abbreviated, time: .shortened)) // 예: 10월 24일 오후 2:30
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        // 말풍선 위치를 별의 살짝 위쪽으로 띄웁니다
                        .position(x: wPt.x, y: wPt.y - 50)
                        .zIndex(100) // 다른 별자리들보다 항상 위에 보이게!
                        .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                    }
                }
            ForEach(sessionStore.completedSessions) { session in
                if completionConstellationId != session.constellationId, let constellation = constellationById(session.constellationId) {
                    let visibleCount = visibleDiscoveredStarCounts[session.constellationId] ?? constellation.starCount
                    let edgeState = edgeRenderState(for: constellation)
                    ConstellationRenderer(
                        constellation: constellation,
                        coordinateMapper: mapper,
                        discoveredStarCount: visibleCount,
                        showEdges: true,
                        edgeProgress: 1,
                        reduceMotion: accessibility.isReduceMotionEnabled,
                        highPerformanceMode: highPerformanceMode,
                        visibleEdgeIndices: edgeState.visibleIndices,
                        edgeVisibilityOverrides: edgeState.visibilityOverrides,
                        starStyle: starStyle,
                        activeBirthEffect: activeStarBirthEffect?.constellationId == constellation.id ? activeStarBirthEffect : nil
                    )
                }
            }

            if let running = sessionStore.currentSession, let constellation = constellationById(running.constellationId) {
                let edgeState = edgeRenderState(for: constellation)
                ConstellationRenderer(constellation: constellation, coordinateMapper: mapper, discoveredStarCount: running.discoveredStarCount, showEdges: true, edgeProgress: 1, reduceMotion: accessibility.isReduceMotionEnabled, highPerformanceMode: highPerformanceMode, visibleEdgeIndices: edgeState.visibleIndices, edgeVisibilityOverrides: edgeState.visibilityOverrides, starStyle: starStyle, activeBirthEffect: activeStarBirthEffect?.constellationId == constellation.id ? activeStarBirthEffect : nil)
            }
        }.frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func interactiveEffectLayer(size: CGSize) -> some View {
        let mapper = coordinateMapper(for: size)
        if let rewardCenter = dailyStarRippleCenter {
            RippleEffectView(
                position: mapper.worldPoint(fromNormalized: rewardCenter),
                reduceMotion: accessibility.isReduceMotionEnabled
            )
            .id("daily-ripple-\(spawnEffectToken)")
            .allowsHitTesting(false)
        }
    }

    private func insertUserConstellationAsCompleted(id: String) {
        Task { @MainActor in
            Self.logger.notice("attempting dev constellation placement id=\(id, privacy: .public)")
            let preferredPlacement = await repository.fetchInsertedUserConstellation(
                id: id,
                userId: localConstellationUserId,
                occupied: placedConstellations,
                randomSeed: Int64(userSeed)
            )
            let inserted: Constellation?
            if let preferredPlacement {
                inserted = preferredPlacement
            } else {
                inserted = await repository.fetchInsertedUserConstellation(
                    id: id,
                    userId: localConstellationUserId,
                    occupied: placedConstellations,
                    randomSeed: Int64(userSeed)
                )
            }

            guard let constellation = inserted else {
                Self.logger.error("dev constellation placement failed id=\(id, privacy: .public)")
                return
            }

            Self.logger.notice("dev constellation placed id=\(id, privacy: .public) constellationId=\(constellation.id.uuidString, privacy: .public) stars=\(constellation.starCount)")
            applyInsertedConstellationAsCompleted(constellation, selectSession: true)
        }
    }

    @MainActor
    private func syncLocalInsertedConstellations() async {
        let existingIds = Set(sessionStore.completedSessions.map(\.constellationId))
        let insertedConstellations = await repository.fetchCustomConstellations(
            userId: localConstellationUserId,
            occupied: placedConstellations,
            randomSeed: Int64(userSeed)
        )

        Self.logger.notice("sync local constellations fetched=\(insertedConstellations.count) existingSessions=\(existingIds.count)")

        for constellation in insertedConstellations where !existingIds.contains(constellation.id) {
            Self.logger.notice("rehydrating local constellation constellationId=\(constellation.id.uuidString, privacy: .public) name=\(constellation.name, privacy: .public)")
            applyInsertedConstellationAsCompleted(constellation, selectSession: false)
        }
    }

    @MainActor
    private func applyInsertedConstellationAsCompleted(_ constellation: Constellation, selectSession: Bool) {
        let endedAt = Date()
        let startedAt = endedAt.addingTimeInterval(-25 * 60)
        let completedSession = FocusSession(
            startedAt: startedAt,
            endedAt: endedAt,
            slotSeconds: 25 * 60,
            constellationId: constellation.id,
            discoveredStarCount: constellation.starCount,
            status: .completed,
            memo: nil
        )

        // Dev insertion should behave like a finished focus session already present in the sky.
        Self.logger.notice("applying inserted constellation as completed constellationId=\(constellation.id.uuidString, privacy: .public) selectSession=\(selectSession)")
        applyCompletedSessionToSky(completedSession, constellation: constellation, selectSession: selectSession)
    }

    @MainActor
    private func applyCompletedSessionToSky(
        _ session: FocusSession,
        constellation: Constellation,
        selectSession: Bool
    ) {
        if !placedConstellations.contains(where: { $0.id == constellation.id }) {
            placedConstellations.append(constellation)
        }

        sessionStore.appendCompletedSession(session)
        Self.logger.notice("completed session applied constellationId=\(constellation.id.uuidString, privacy: .public) sessionId=\(session.id.uuidString, privacy: .public) discovered=\(session.discoveredStarCount)")
        visibleDiscoveredStarCounts[constellation.id] = session.discoveredStarCount
        edgeRevealStates[constellation.id] = EdgeRevealState(
            committedDiscoveredCount: session.discoveredStarCount,
            pendingDiscoveredCount: nil,
            progress: 0
        )

        if selectSession {
            selectedSession = session
        }
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

    @MainActor
        private func refreshSky() async {
            guard !isFetchingSky else { return }
            isFetchingSky = true
            defer { isFetchingSky = false }

            do {
                let sky = try await viewModel.fetchMySky(userSeed: Int64(userSeed))
                userSeed = Int(sky.seed)
                
                // 🚨🚨🚨 [핵심 수정] 🚨🚨🚨
                // 기존에 있던 fetchedStars 관련 코드를 완전히 삭제합니다!
                // 서버의 임시 데이터가 우리가 기기에 예쁘게 저장해둔 별 위치와 시간을 덮어쓰지 못하게 막습니다.
                // 이제 onAppear에서 부른 parseDailyStars()의 데이터가 절대적으로 유지됩니다.

                let mergedSky = mergeRemoteSkyWithLocalState(sky)
                remoteFocusLayoutItems = mergedSky.remoteFocusLayoutItems
                placedConstellations = mergedSky.constellations
                sessionStore.replaceCompletedSessions(mergedSky.completedSessions)
                visibleDiscoveredStarCounts = Dictionary(uniqueKeysWithValues: mergedSky.completedSessions.map { ($0.constellationId, $0.discoveredStarCount) })
                edgeRevealStates = Dictionary(
                    uniqueKeysWithValues: mergedSky.completedSessions.map {
                        (
                            $0.constellationId,
                            EdgeRevealState(
                                committedDiscoveredCount: $0.discoveredStarCount,
                                pendingDiscoveredCount: nil,
                                progress: 0
                            )
                        )
                    }
                )
            } catch {
                Self.logger.error("sky fetch failed: \(error.localizedDescription)")
            }
        }
    
    private var localConstellationUserId: String {
        userId.isEmpty ? fallbackLocalUserId : userId
    }

    private func mergeRemoteSkyWithLocalState(_ remoteSky: MySkySnapshot) -> MySkySnapshot {
        let remoteServerSessionIds = Set(remoteSky.completedSessions.compactMap(\.serverSessionId))
        let localSessionsToPreserve = sessionStore.completedSessions.filter { session in
            guard let constellation = placedConstellations.first(where: { $0.id == session.constellationId }) else {
                return false
            }

            _ = constellation
            guard let serverSessionId = session.serverSessionId else {
                return true
            }

            return !remoteServerSessionIds.contains(serverSessionId)
        }

        let localConstellationsToPreserve = localSessionsToPreserve.compactMap { session in
            placedConstellations.first(where: { $0.id == session.constellationId })
        }

        let mergedSessions = mergedFocusSessions(remote: remoteSky.completedSessions, local: localSessionsToPreserve)
        let mergedConstellations = mergedConstellations(remote: remoteSky.constellations, local: localConstellationsToPreserve)

        return MySkySnapshot(
            seed: remoteSky.seed,
            dailyStars: remoteSky.dailyStars,
            remoteFocusLayoutItems: remoteSky.remoteFocusLayoutItems,
            completedSessions: mergedSessions,
            constellations: mergedConstellations
        )
    }

    private func rebuildRemoteFocusLayout() {
        let layout = viewModel.layoutFocusConstellations(remoteFocusLayoutItems, userSeed: Int64(userSeed))
        applyRemoteFocusLayout(layout)
    }

    private func applyRemoteFocusLayout(_ layout: [FocusSkyLayoutResult]) {
        let remoteCompletedSessions = layout
            .filter { $0.item.status == .completed }
            .map(\.session)
        let remoteConstellations = layout.map(\.constellation)
        let remoteSessionIds = Set(layout.map { $0.item.sessionId })

        let localSessions = preservedLocalSessions(excludingRemoteSessionIds: remoteSessionIds)
        let localConstellations = localSessions.compactMap { session in
            placedConstellations.first(where: { $0.id == session.constellationId })
        }

        placedConstellations = mergedConstellations(remote: remoteConstellations, local: localConstellations)
        sessionStore.replaceCompletedSessions(mergedFocusSessions(remote: remoteCompletedSessions, local: localSessions))
    }

    private func preservedLocalSessions(excludingRemoteSessionIds remoteSessionIds: Set<String>) -> [FocusSession] {
        sessionStore.completedSessions.filter { session in
            guard placedConstellations.contains(where: { $0.id == session.constellationId }) else {
                return false
            }

            guard let serverSessionId = session.serverSessionId else {
                return true
            }

            return !remoteSessionIds.contains(serverSessionId)
        }
    }

    private func mergedFocusSessions(remote: [FocusSession], local: [FocusSession]) -> [FocusSession] {
        var result: [FocusSession] = remote
        let existingKeys = Set(remote.map(sessionIdentityKey))

        for session in local where !existingKeys.contains(sessionIdentityKey(session)) {
            result.append(session)
        }

        return result.sorted { lhs, rhs in
            (lhs.endedAt ?? lhs.startedAt) > (rhs.endedAt ?? rhs.startedAt)
        }
    }

    private func mergedConstellations(remote: [Constellation], local: [Constellation]) -> [Constellation] {
        var result: [Constellation] = remote
        var seenIds = Set(remote.map(\.id))

        for constellation in local where seenIds.insert(constellation.id).inserted {
            result.append(constellation)
        }

        return result
    }

    private func sessionIdentityKey(_ session: FocusSession) -> String {
        if let serverSessionId = session.serverSessionId {
            return "server:\(serverSessionId)"
        }
        return "local:\(session.id.uuidString)"
    }

    @MainActor
    private func saveCompletedSessionMemo(_ memo: SessionMemo) async -> Bool {
        guard let pendingMemoSessionId else { return false }
        guard let session = sessionStore.completedSessions.first(where: { $0.id == pendingMemoSessionId }) else { return false }
        guard let serverSessionId = session.serverSessionId, let serverConstellationId = session.serverConstellationId else {
            sessionStore.updateMemo(sessionId: pendingMemoSessionId, memo: memo)
            return true
        }

        let endedAt = session.endedAt ?? Date()
        let request = FocusSessionSaveRequestDTO(
            sessionId: serverSessionId,
            constellationId: serverConstellationId,
            startedAt: session.startedAt.ISO8601Format(),
            endedAt: endedAt.ISO8601Format(),
            slotSeconds: session.slotSeconds,
            discoveredStarCount: session.discoveredStarCount,
            topicTags: memo.topicTags,
            rating: memo.rating,
            freeText: memo.freeText
        )

        do {
            try await viewModel.saveCompletedSession(request)
            sessionStore.updateMemo(sessionId: pendingMemoSessionId, memo: memo)
            await refreshSky()
            return true
        } catch {
            Self.logger.error("focus save failed: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - 일일 보상용 황금 별 디자인, Shape, 파동 애니메이션 유지
private struct DailyRewardStarNode: View {
    @State private var isBlinking = false
    var body: some View {
        let size: CGFloat = 16
        let color = Color(red: 1.0, green: 0.9, blue: 0.6)
        ZStack {
            Circle().fill(color.opacity(0.3)).frame(width: size * 2.5, height: size * 2.5).blur(radius: size * 0.4).opacity(isBlinking ? 1.0 : 0.5)
            RewardStarShape(innerRatio: 0.35).fill(RadialGradient(colors: [.white, color], center: .center, startRadius: 0, endRadius: size / 2)).frame(width: size, height: size)
        }.onAppear { withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { isBlinking = true } }
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
