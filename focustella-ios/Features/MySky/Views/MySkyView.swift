// 📂 Features/MySky/Views/MySkyView.swift
import SwiftUI
import Combine
import os

struct MySkyView: View {
    private static let logger = Logger(subsystem: "focustella-ios", category: "FocusSession")
    private let dailySessionSheetBuilder: (Bool) -> AnyView

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = MySkyViewModel()
    @StateObject private var sessionStore: FocusSessionRuntimeStore
    @StateObject private var accessibility = AppAccessibility.shared
    @StateObject private var devInsertionCoordinator = DevInsertionCoordinator()
    @StateObject private var inputProtectionCoordinator = MySkyInputProtectionCoordinator()
    @StateObject private var blackHoleCoordinator = MySkyBlackHoleCoordinator()
    @StateObject private var dailyRewardStore = MySkyDailyRewardStore()
    @StateObject private var effectsCoordinator = MySkyEffectsCoordinator()
    @AppStorage("highPerformanceMode") private var highPerformanceMode: Bool = false
    @AppStorage("developerMode") private var developerMode: Bool = false
    @AppStorage("starStyle") private var starStyle: StarAppearanceStyle = .realistic
    @AppStorage("mySkyBackgroundVariant") private var backgroundVariant: MySkyBackgroundVariant = .singularity
    @AppStorage("userId") private var userId: String = ""
    @AppStorage("userSeed") private var userSeed: Int = 0
    
    // 🔥 튜토리얼 진행 상태 저장
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    @State private var tutorialStep: TutorialStep = .notStarted

    private let repository = ConstellationRepository()
    private let sessionDirector = MySkySessionDirector()
    private let interactionController = MySkyInteractionController()
    private let renderModel = MySkyRenderModel()
    private let tutorialCoordinator = MySkyTutorialCoordinator()

    @State private var cameraState: MySkyCameraState = .default
    @State private var dragStartCamera: MySkyCameraState?
    @State private var magnifyStartZoom: CGFloat?
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
    @State private var cameraTransitionTask: Task<Void, Never>?
    @State private var tutorialWarpTask: Task<Void, Never>?
    @State private var showCompletionOverlay = false
    @State private var showCompletionRecordButton = false
    @State private var completionFlowTask: Task<Void, Never>?
    @State private var completionEdgeOrder: [Int] = []
    @State private var hasLaidOutCTA = false
    @State private var hasInitializedView = false
    @State private var blackHolePrePresentationCamera: MySkyCameraState?
    @State private var skyState = MySkySceneState()
    @State private var edgeRevealTokens: [UUID: Int] = [:]
    @State private var isFetchingSky = false
    @State private var livePresentationState: FocusSessionPresentationState = .idle
    
    private let ctaFadeDuration: Double = 0.38
    private let ctaIdleDelay: Double = 1.5
    private let sessionAutoZoom: CGFloat = 2.0
    private let blackHolePresentationZoom: CGFloat = 0.22
    private let blackHolePreludeDelay: TimeInterval = 1.05
    private let tutorialSessionZoom: CGFloat = 1.35

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let fallbackLocalUserId = "local-user"

    private var isSkyInteractionLocked: Bool {
        pendingMemoSessionId != nil ||
        showMemoSheet ||
        tutorialStep != .done ||
        inputProtectionCoordinator.isActive ||
        blackHoleCoordinator.isInputLocked
    }

    private var canRunBlackHoleEffect: Bool {
        tutorialStep == .done &&
        sessionStore.currentSession == nil &&
        !showMemoSheet &&
        pendingMemoSessionId == nil
    }

    private var skyLayerOpacityForBlackHole: Double {
        switch blackHoleCoordinator.phase {
        case .stage7Spawning, .stage7Absorbing, .stage7AwaitingInput, .stage8Collapsing, .blackout:
            return 0
        case .whiteFlash:
            return 0
        default:
            return 1
        }
    }

    private var blackHoleBackgroundOpacity: Double {
        let overlayOpacity = Double(max(0, min(1, blackHoleCoordinator.overlay.opacity)))
        let blackout = Double(max(0, min(1, blackHoleCoordinator.absorption.blackout)))

        switch blackHoleCoordinator.phase {
        case .stage7Spawning:
            return min(0.86, 0.08 + overlayOpacity * 0.82)
        case .stage7Absorbing:
            return min(0.94, 0.46 + overlayOpacity * 0.38 + blackout * 0.22)
        case .stage7AwaitingInput:
            return 0.92
        case .stage8Collapsing:
            return max(0, 0.06 + overlayOpacity * 0.62)
        case .blackout:
            return 1
        case .whiteFlash:
            return max(0.82, Double(blackHoleCoordinator.whiteFlashOpacity))
        default:
            return 0
        }
    }

    private var stateMerger: MySkyStateMerger {
        MySkyStateMerger(
            placedConstellations: skyState.constellations,
            completedSessions: sessionStore.completedSessions
        )
    }

    init(
        sessionStore: @autoclosure @escaping () -> FocusSessionRuntimeStore,
        dailySessionSheetBuilder: @escaping (Bool) -> AnyView = { _ in AnyView(EmptyView()) }
    ) {
        _sessionStore = StateObject(wrappedValue: sessionStore())
        self.dailySessionSheetBuilder = dailySessionSheetBuilder
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let ctaBottomInset = max(36, proxy.safeAreaInsets.bottom + 94)
            
            ZStack(alignment: .topLeading) {
                MySkyBackgroundLayer(
                    canvasSize: size,
                    safeAreaInsets: proxy.safeAreaInsets,
                    scale: cameraState.zoom,
                    offset: coordinateMapper(for: size).renderOffset(for: cameraState),
                    variant: backgroundVariant
                )
                interactiveSkyLayer(size: size)
                blackHoleVisualLayer(size: size)
                
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
                                sessionStore.resume(remainingStars: remainingStars)
                            },
                            onCancel: {
                                cameraTransitionTask?.cancel()
                                tutorialWarpTask?.cancel()
                                if let serverSessionId = sessionStore.currentSession?.serverSessionId {
                                    skyState.removeRemoteLayoutItem(sessionId: serverSessionId)
                                    rebuildRemoteFocusLayout()
                                } else if let constellationId = sessionStore.currentSession?.constellationId {
                                    skyState.removeConstellations(ids: [constellationId])
                                }
                                sessionStore.cancel()
                                livePresentationState.reset()
                                animateCamera(to: .default, duration: 0.62)
                                scheduleCTA()
                            },
                            onAdvanceNextStar: {
                                let result = sessionStore.advanceToNextStar(totalStars: constellation.starCount)
                                if let completed = result.completed {
                                    handleSessionCompleted(completed)
                                    reconcileLivePresentation(constellation: constellation, size: size)
                                }
                            },
                            onAdvanceFinalStar: {
                                prepareFinalStarOnlyBirth(constellation: constellation, size: size)
                                if sessionStore.advanceToFinalStar(totalStars: constellation.starCount, leadSeconds: 0) {
                                    syncSession(now: Date())
                                }
                            }
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
                
                if effectsCoordinator.showDailyRewardText {
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
                            animateCamera(to: .default, duration: 1.2) // 🔥 카메라 원래대로
                        }
                    )
                }
            }
            .overlay(alignment: .topTrailing) {
                if developerMode {
                    DevInsertionToolView(
                        starStyle: $starStyle,
                        coordinator: devInsertionCoordinator,
                        fixedUserSeed: Int64(userSeed),
                        isSessionRunning: sessionStore.currentSession != nil,
                        onPlaceNextBatch: {
                            devInsertionCoordinator.placeNextBatch(context: devInsertionContext)
                        },
                        onReset: {
                            devInsertionCoordinator.reset(context: devInsertionContext)
                        },
                        onPrimeEasterEgg: {
                            inputProtectionCoordinator.setActivationCountForDebug(6)
                            interactionController.prepareForNextProtectionActivation()
                            Haptics.light()
                        }
                    )
                    .padding(.top, proxy.safeAreaInsets.top + 56)
                    .padding(.trailing, 20)
                }
            }
            .overlay(alignment: .top) {
                if inputProtectionCoordinator.isBannerVisible {
                    InputProtectionBannerView(message: inputProtectionCoordinator.bannerMessage)
                    .padding(.top, proxy.safeAreaInsets.top + 64)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onDisappear {
                effectsCoordinator.cancelDailyRewardEffects()
                dailyRewardStore.clearSelection()
                inputProtectionCoordinator.reset()
                inputProtectionCoordinator.resetActivationProgress()
                interactionController.prepareForNextProtectionActivation()
                blackHoleCoordinator.resetAfterCooldown()
                blackHolePrePresentationCamera = nil
                devInsertionCoordinator.reset(context: devInsertionContext)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("MySky").font(.largeTitle.bold()).foregroundStyle(.white)
                }
            }
            .onAppear {
                canvasSize = size
                dailyRewardStore.loadFromStorage()
                blackHoleCoordinator.setFeatureEnabled(canRunBlackHoleEffect)
                guard !hasInitializedView else { return }

                hasInitializedView = true
                
                tutorialStep = tutorialCoordinator.initialStep(hasSeenTutorial: hasSeenTutorial)
                cameraState = tutorialCoordinator.initialCamera(hasSeenTutorial: hasSeenTutorial)

                showCTA = sessionStore.currentSession == nil
                hasLaidOutCTA = true

                // Keep the first sky fetch on initial mount only so tab switches do not
                // recreate the whole sky state and trigger another expensive re-render.
                Task {
                    await refreshSky()
                    await devInsertionCoordinator.syncLocalInsertedConstellations(context: devInsertionContext)
                }
            }
            .onChange(of: developerMode) { _, enabled in
                if !enabled {
                    devInsertionCoordinator.reset(context: devInsertionContext)
                }
            }
            .onChange(of: canRunBlackHoleEffect) { _, enabled in
                blackHoleCoordinator.setFeatureEnabled(enabled)
                if !enabled {
                    inputProtectionCoordinator.resetActivationProgress()
                    blackHolePrePresentationCamera = nil
                }
            }
            .onChange(of: inputProtectionCoordinator.isActive) { _, isActive in
                if !isActive {
                    interactionController.prepareForNextProtectionActivation()
                }
            }
            .onChange(of: blackHoleCoordinator.phase) { oldValue, newValue in
                handleBlackHolePhaseChange(from: oldValue, to: newValue)
            }
            .onChange(of: size) { _, newValue in canvasSize = newValue }
            .onReceive(tick) { now in syncSession(now: now) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    dailyRewardStore.loadFromStorage()
                    syncSession(now: Date())
                    scheduleCTA()
                    Task { await devInsertionCoordinator.syncLocalInsertedConstellations(context: devInsertionContext) }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didInsertUserConstellation)) { notification in
                let extractedId: String? = (notification.object as? String) ?? (notification.object as? String?)?.flatMap { $0 }
                guard let insertedId = extractedId else { return }
                Self.logger.notice("received dev constellation notification id=\(insertedId, privacy: .public)")
                Task {
                    await devInsertionCoordinator.insertUserConstellationAsCompleted(
                        id: insertedId,
                        context: devInsertionContext
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dailySessionCompleted)) { _ in
                if let nextStep = tutorialCoordinator.stepAfterDailySessionCompleted(
                    hasSeenTutorial: hasSeenTutorial,
                    step: tutorialStep
                ) {
                    tutorialStep = nextStep
                    triggerTutorialRewardSequence(size: canvasSize)
                } else {
                    triggerDailyRewardSequence(size: canvasSize)
                }
            }
            .sheet(isPresented: $showSlotPicker) { SlotPickerSheet { seconds in requestStartSession(slotSeconds: seconds) } }
            .sheet(isPresented: $showDailySessionSheet) {
                dailySessionSheetBuilder(hasSeenTutorial)
            }
            // 🔥 튜토리얼 강제 종료(탈옥) 방지 로직 추가!
            .onChange(of: showDailySessionSheet) { _, isShowing in
                if tutorialCoordinator.shouldRollbackDailySheetDismissal(
                    isShowing: isShowing,
                    hasSeenTutorial: hasSeenTutorial,
                    step: tutorialStep
                ) {
                    Self.logger.notice("tutorial escape detected while waiting daily session; rollback to suggestDaily")
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
                        livePresentationState.reset()
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                            showCompletionOverlay = false
                            showCompletionRecordButton = false
                        }
                    }
                    return didSave
                }
            }
            .overlay(alignment: .bottom) {
                MySkyBottomCTAView(
                    isVisible: showCTA && sessionStore.currentSession == nil && tutorialStep == .done,
                    hasLaidOut: hasLaidOutCTA,
                    fadeDuration: ctaFadeDuration,
                    bottomInset: ctaBottomInset,
                    onTapDaily: { showDailySessionSheet = true },
                    onTapFocus: { showSlotPicker = true }
                )
            }
        } // ZStack 닫기
        .preferredColorScheme(.dark)
    }

    // MARK: - 🔥 튜토리얼 타임워프 세션 로직
    private func startTutorialWarpSession(size: CGSize) {
        Task { @MainActor in
            guard let constellation = await repository.fetchSessionConstellation(
                durationSeconds: 300,
                occupied: skyState.constellations,
                userId: localConstellationUserId,
                randomSeed: Int64(userSeed)
            ) else { return }

            beginLiveSession(
                constellation: constellation,
                slotSeconds: 300,
                startedAt: Date(),
                clock: .tutorial(),
                serverSessionId: nil,
                serverConstellationId: nil,
                size: size
            )

            tutorialWarpTask?.cancel()
            tutorialWarpTask = Task { @MainActor in
                while tutorialStep == .warping, sessionStore.currentStatus() == .running {
                    if tutorialWarpCanAdvance {
                        sessionStore.fastForwardTutorial(by: livePresentationState.clock.tutorialStepSeconds ?? 6)
                        syncSession(now: Date())
                    }
                    try? await Task.sleep(for: .seconds(livePresentationState.clock.pollInterval))
                }
            }
        }
    }

    private func makeRewardPoint(xRange: ClosedRange<CGFloat>, yRange: ClosedRange<CGFloat>) -> CGPoint {
        MySkyRewardPlanner(
            constellations: skyState.constellations,
            dailyStars: dailyRewardStore.stars
        ).makeRewardPoint(xRange: xRange, yRange: yRange)
    }

    // 1. 일일 세션 완료용
    private func triggerDailyRewardSequence(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let newPoint = makeRewardPoint(xRange: 0.15...0.85, yRange: 0.1...0.5)
        runRewardSequence(point: newPoint, size: size, cleanupDelay: 3.0) {
            effectsCoordinator.showDailyRewardTextTemporarily(duration: 3.0)
        }
    }

    // 2. 튜토리얼 전용 보상 시퀀스
    private func triggerTutorialRewardSequence(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let newPoint = tutorialCoordinator.goldenStarSkyPoint
        runRewardSequence(point: newPoint, size: size, cleanupDelay: 2.0) {
            tutorialCoordinator.applyDailyRewardImpact(step: $tutorialStep)
        }
    }

    private func runRewardSequence(
        point: CGPoint,
        size: CGSize,
        cleanupDelay: TimeInterval,
        onImpact: @escaping @MainActor () -> Void
    ) {
        let targetCamera = cameraController(for: size).centeredCamera(forSky: point, zoom: 1.6)
        effectsCoordinator.runDailyRewardSequence(
            point: point,
            targetCamera: targetCamera,
            cleanupDelay: cleanupDelay,
            animateCamera: { targetCamera, duration in
                animateCamera(to: targetCamera, duration: duration)
            },
            appendReward: { point in
                dailyRewardStore.append(point)
            },
            clearSelection: {
                dailyRewardStore.clearSelection()
            },
            onImpact: onImpact,
            onCleanup: {
                animateCamera(to: .default, duration: 1.2)
            }
        )
    }
    // MARK: - 기존 로직 유지
    private func constellationById(_ id: UUID) -> Constellation? { skyState.constellation(id: id) }

    private func renderMetadataById(_ id: UUID) -> MySkyConstellationRenderMetadata? {
        skyState.renderMetadata(id: id)
    }

    private func requestStartSession(slotSeconds: Int) {
        Task { @MainActor in
            guard sessionStore.currentSession == nil else { return }
            let normalizedSeconds = max(5 * 60, slotSeconds)
            do {
                let created = try await viewModel.createFocusSession(durationMinutes: normalizedSeconds / 60)
                let startedAt = Date()
                let createdItem = viewModel.makeCreatedFocusLayoutItem(
                    created,
                    startedAt: startedAt,
                    slotSeconds: normalizedSeconds
                )
                skyState.appendRemoteLayoutItem(createdItem)

                guard let createdResult = viewModel.placeFocusLayoutItem(
                    createdItem,
                    occupied: skyState.constellations,
                    userSeed: Int64(userSeed)
                ) else {
                    skyState.removeRemoteLayoutItem(sessionId: created.focusSessionId)
                    Self.logger.error("focus create placement failed for sessionId=\(created.focusSessionId)")
                    return
                }

                let constellation = createdResult.constellation
                guard !constellation.stars.isEmpty else {
                    skyState.removeRemoteLayoutItem(sessionId: created.focusSessionId)
                    return
                }

                skyState.upsertConstellation(constellation)
                beginLiveSession(
                    constellation: constellation,
                    slotSeconds: normalizedSeconds,
                    startedAt: startedAt,
                    clock: .live,
                    serverSessionId: created.focusSessionId,
                    serverConstellationId: created.constellationId,
                    size: canvasSize
                )
                selectedSession = nil
                showCTA = false
            } catch {
                Self.logger.error("focus create failed: \(error.localizedDescription)")
            }
        }
    }

    private var sessionDirectorContext: MySkySessionDirector.Context {
        MySkySessionDirector.Context(
            sessionStore: sessionStore,
            skyState: $skyState,
            livePresentationState: $livePresentationState,
            activeStarBirthEffect: $activeStarBirthEffect,
            spawnEffectToken: $spawnEffectToken,
            tutorialWarpTask: $tutorialWarpTask,
            completionFlowTask: $completionFlowTask,
            pendingMemoSessionId: $pendingMemoSessionId,
            selectedSession: $selectedSession,
            completionConstellation: $completionConstellation,
            completionEdgeOrder: $completionEdgeOrder,
            showCompletionOverlay: $showCompletionOverlay,
            showCompletionRecordButton: $showCompletionRecordButton,
            canvasSize: $canvasSize,
            constellationById: { id in
                constellationById(id)
            },
            cameraForSky: { point, zoom, size in
                cameraController(for: size).centeredCamera(forSky: point, zoom: zoom)
            },
            cameraForStar: { star, zoom, size in
                cameraController(for: size).centeredCamera(forStar: star, zoom: zoom)
            },
            logCameraTarget: { reason, targetSky, size, targetCamera in
                logCameraTarget(reason: reason, targetSky: targetSky, size: size, targetCamera: targetCamera)
            },
            animateCamera: { targetCamera, duration, completion in
                animateCamera(to: targetCamera, duration: duration, completion: completion)
            },
            triggerSpawnEffectIfNeeded: { constellation, discoveredCount in
                triggerSpawnEffectIfNeeded(constellation: constellation, discoveredCount: discoveredCount)
            },
            scheduleVisibleEdgeReveal: { constellationId, discoveredCount, delay in
                scheduleVisibleEdgeReveal(constellationId: constellationId, discoveredCount: discoveredCount, after: delay)
            },
            beginEdgeRevealAnimation: { constellation, discoveredCount, duration in
                beginEdgeRevealAnimation(constellation: constellation, discoveredCount: discoveredCount, duration: duration)
            },
            focusOnConstellationOverview: { constellation, size in
                focusOnConstellationOverview(constellation, size: size)
            },
            tutorialSessionZoom: tutorialSessionZoom,
            sessionAutoZoom: sessionAutoZoom
        )
    }

    private var devInsertionContext: DevInsertionCoordinator.Context {
        DevInsertionCoordinator.Context(
            skyState: $skyState,
            edgeRevealTokens: $edgeRevealTokens,
            selectedSession: $selectedSession,
            sessionStore: sessionStore,
            repository: repository,
            localUserId: localConstellationUserId,
            userSeed: Int64(userSeed)
        )
    }

    @MainActor
    private func beginLiveSession(
        constellation: Constellation,
        slotSeconds: Int,
        startedAt: Date,
        clock: FocusSessionClock,
        serverSessionId: String?,
        serverConstellationId: Int?,
        size: CGSize
    ) {
        sessionDirector.beginLiveSession(
            constellation: constellation,
            slotSeconds: slotSeconds,
            startedAt: startedAt,
            clock: clock,
            serverSessionId: serverSessionId,
            serverConstellationId: serverConstellationId,
            size: size,
            context: sessionDirectorContext
        )
    }

    private func beginLivePresentation(for constellation: Constellation, clock: FocusSessionClock, size: CGSize) {
        sessionDirector.beginLivePresentation(
            for: constellation,
            clock: clock,
            size: size,
            context: sessionDirectorContext
        )
    }

    private func movePresentationCamera(toOrderIndex orderIndex: Int, constellation: Constellation, size: CGSize) {
        sessionDirector.movePresentationCamera(
            toOrderIndex: orderIndex,
            constellation: constellation,
            size: size,
            context: sessionDirectorContext
        )
    }

    private func reconcileLivePresentation(constellation: Constellation, size: CGSize) {
        sessionDirector.reconcileLivePresentation(
            constellation: constellation,
            size: size,
            context: sessionDirectorContext
        )
    }

    private func beginBirthPresentation(constellation: Constellation, size: CGSize) {
        sessionDirector.beginBirthPresentation(
            constellation: constellation,
            size: size,
            context: sessionDirectorContext
        )
    }

    private func syncSession(now: Date) {
        sessionDirector.syncSession(now: now, context: sessionDirectorContext)
    }

    private func handleSessionCompleted(_ completed: FocusSession) {
        sessionDirector.handleSessionCompleted(completed, context: sessionDirectorContext)
    }

    private func startCompletionWrapUp(constellation: Constellation, size: CGSize) {
        sessionDirector.startCompletionWrapUp(
            constellation: constellation,
            size: size,
            context: sessionDirectorContext
        )
    }

    private func prepareFinalStarOnlyBirth(constellation: Constellation, size: CGSize) {
        sessionDirector.prepareFinalStarOnlyBirth(
            constellation: constellation,
            size: size,
            context: sessionDirectorContext
        )
    }
    
    private func registerInteraction() {
        if showCTA { withAnimation(.easeInOut(duration: ctaFadeDuration)) { showCTA = false } }
        // User pan/zoom should immediately take over camera control.
        cameraTransitionTask?.cancel()
        isInteracting = true
        ctaTask?.cancel()
    }

    private func endInteraction() {
        isInteracting = false
        scheduleCTA()
    }

    private func handleInputPressureDetected() {
        let duration: TimeInterval = 3.0
        let didActivate = inputProtectionCoordinator.activate(duration: duration) {
            // Cancel ongoing gesture states and return to initial sky camera while input is locked.
            dragStartCamera = nil
            magnifyStartZoom = nil
            isInteracting = false
            animateCamera(to: .default, duration: 0.42)
        }

        guard didActivate else { return }

        if canRunBlackHoleEffect {
            let activationCount = inputProtectionCoordinator.activationCount
            blackHoleCoordinator.registerProtectionActivation(
                activationCount: activationCount,
                reduceMotion: accessibility.isReduceMotionEnabled,
                preSpawnDelay: activationCount >= 7 ? blackHolePreludeDelay : 0
            )
        }

        Haptics.warning()
        let payload: [String: Any] = [
            "event": "input-protection-activated",
            "activationCount": inputProtectionCoordinator.activationCount,
            "durationSeconds": duration
        ]
        Self.logger.notice("\(LogJSONFormatter.compact(payload), privacy: .public)")
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

    private var interactionContext: MySkyInteractionController.Context {
        MySkyInteractionController.Context(
            cameraState: $cameraState,
            dragStartCamera: $dragStartCamera,
            magnifyStartZoom: $magnifyStartZoom,
            selectedSession: $selectedSession,
            dailyStars: dailyRewardStore.stars,
            selectedDailyStar: dailyRewardStore.selectedStar,
            onSelectDailyStar: { item in
                dailyRewardStore.select(item)
            },
            completionConstellationId: completionConstellation?.id,
            liveConstellationId: livePresentationState.constellationId,
            completedSessions: sessionStore.completedSessions,
            canvasSize: canvasSize,
            coordinateMapper: { size in
                coordinateMapper(for: size)
            },
            cameraController: { size in
                cameraController(for: size)
            },
            constellationById: { id in
                constellationById(id)
            },
            onInteractionBegan: registerInteraction,
            onInteractionEnded: endInteraction,
            onInputPressureDetected: handleInputPressureDetected,
            onInputStressChanged: { stress in
                if canRunBlackHoleEffect {
                    blackHoleCoordinator.updateStress(score: stress)
                } else {
                    blackHoleCoordinator.updateStress(score: 0)
                }
            }
        )
    }

    private func dragGesture() -> some Gesture {
        interactionController.dragGesture(context: interactionContext)
    }

    private func magnificationGesture() -> some Gesture {
        interactionController.magnificationGesture(context: interactionContext)
    }

    private func sessionTapGesture(size: CGSize) -> some Gesture {
        interactionController.sessionTapGesture(size: size, context: interactionContext)
    }

    @ViewBuilder
    private func interactiveSkyLayer(size: CGSize) -> some View {
        let shouldRenderSkyLayer = skyLayerOpacityForBlackHole > 0.001
        let shouldUseSharedTimeline = !isInteracting && (((highPerformanceMode && !accessibility.isReduceMotionEnabled) || activeStarBirthEffect != nil))
        let renderedSky = Group {
            if !shouldRenderSkyLayer {
                Color.clear
            } else if shouldUseSharedTimeline {
                TimelineView(.periodic(from: .now, by: 1.0 / 8.0)) { context in
                    skyCanvas(size: size, animationTime: context.date.timeIntervalSinceReferenceDate)
                        .overlay {
                            // Keep effect rendering in the same projected screen space as stars.
                            interactiveEffectLayer(size: size)
                                .frame(width: size.width, height: size.height)
                        }
                }
            } else {
                skyCanvas(size: size, animationTime: nil)
                    .overlay {
                        // Keep effect rendering in the same projected screen space as stars.
                        interactiveEffectLayer(size: size)
                            .frame(width: size.width, height: size.height)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())

        let interactionContainer = ZStack {
            renderedSky
                .opacity(skyLayerOpacityForBlackHole)
                .animation(.easeInOut(duration: 0.24), value: skyLayerOpacityForBlackHole)
        }
        .frame(width: size.width, height: size.height)

        if isSkyInteractionLocked {
            interactionContainer.allowsHitTesting(false)
        } else if sessionStore.currentSession == nil {
            interactionContainer
                .simultaneousGesture(sessionTapGesture(size: size))
                .gesture(dragGesture())
                .simultaneousGesture(magnificationGesture())
        } else {
            interactionContainer
        }
    }

    private func focusSessionPresentation(for constellation: Constellation) -> MySkyFocusSessionPresentation {
        renderModel.focusSessionPresentation(
            for: constellation,
            livePresentationState: livePresentationState,
            currentSession: sessionStore.currentSession,
            latestSession: sessionStore.latestSession(constellationId: constellation.id),
            visibleDiscoveredStarCounts: skyState.visibleDiscoveredStarCounts,
            edgeRevealStates: skyState.edgeRevealStates,
            activeStarBirthEffect: activeStarBirthEffect,
            renderMetadata: renderMetadataById(constellation.id)
        )
    }

    private func focusOnConstellationOverview(_ constellation: Constellation, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let targetCamera = cameraController(for: size).overviewCamera(for: constellation)
        logCameraTarget(
            reason: "focus-overview constellation=\(constellation.id.uuidString)",
            targetSky: ConstellationGeometry(constellation: constellation).visualFocusPoint,
            size: size,
            targetCamera: targetCamera
        )
        animateCamera(to: targetCamera, duration: 1.05) {
            guard livePresentationState.constellationId == constellation.id else { return }
            if tutorialStep == .warping {
                pendingMemoSessionId = nil
                livePresentationState.reset()
                withAnimation { tutorialStep = .constellationDone }
            } else {
                livePresentationState.phase = .awaitingMemo
                withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                    showCompletionOverlay = true
                    showCompletionRecordButton = false
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.55))
                    guard livePresentationState.phase == .awaitingMemo else { return }
                    withAnimation(.spring(response: 0.46, dampingFraction: 0.88)) {
                        showCompletionRecordButton = true
                    }
                }
            }
        }
    }

    private func logCameraTarget(reason: String, targetSky: CGPoint, size: CGSize, targetCamera: MySkyCameraState) {
        guard developerMode else { return }
        let mapper = coordinateMapper(for: size)
        let canvasTarget = mapper.canvasPoint(fromSky: targetSky)
        let roundedZoom = (Double(targetCamera.zoom) * 1_000).rounded() / 1_000
        let payload: [String: Any] = [
            "event": "camera-target",
            "reason": reason,
            "skyTarget": LogJSONFormatter.point(targetSky),
            "canvasTarget": LogJSONFormatter.point(canvasTarget),
            "currentCameraCenterSky": LogJSONFormatter.point(cameraState.centerSky),
            "cameraCenterSky": LogJSONFormatter.point(targetCamera.centerSky),
            "screenCenter": LogJSONFormatter.point(mapper.screenCenter, precision: 1),
            "zoom": roundedZoom
        ]
        Self.logger.notice(
            "\(LogJSONFormatter.pretty(payload), privacy: .public)"
        )
    }

    private func animateCamera(
        to targetCamera: MySkyCameraState,
        duration: TimeInterval,
        completion: (@MainActor () -> Void)? = nil
    ) {
        cameraTransitionTask?.cancel()
        let startCamera = cameraState
        let frameCount = max(12, Int(duration * 30))

        cameraTransitionTask = Task { @MainActor in
            for step in 1...frameCount {
                guard !Task.isCancelled else { return }
                let t = CGFloat(step) / CGFloat(frameCount)
                let eased = t * t * (3 - 2 * t)
                cameraState = MySkyCameraState(
                    centerSky: CGPoint(
                        x: startCamera.centerSky.x + (targetCamera.centerSky.x - startCamera.centerSky.x) * eased,
                        y: startCamera.centerSky.y + (targetCamera.centerSky.y - startCamera.centerSky.y) * eased
                    ),
                    zoom: startCamera.zoom + (targetCamera.zoom - startCamera.zoom) * eased
                )
                try? await Task.sleep(for: .seconds(duration / Double(frameCount)))
            }
            guard !Task.isCancelled else { return }
            cameraState = targetCamera
            completion?()
        }
    }

    @discardableResult
    private func triggerSpawnEffectIfNeeded(constellation: Constellation, discoveredCount: Int) -> TimeInterval {
        let presentation = focusSessionPresentation(for: constellation)
        guard let star = presentation.birthStar(for: discoveredCount) else { return 0 }
        if developerMode {
            let payload: [String: Any] = [
                "event": "star-birth",
                "constellationId": constellation.id.uuidString,
                "discoveredCount": discoveredCount,
                "starId": star.id.uuidString,
                "skyTarget": LogJSONFormatter.point(CGPoint(x: star.x, y: star.y))
            ]
            Self.logger.notice(
                "\(LogJSONFormatter.pretty(payload), privacy: .public)"
            )
        }
        spawnEffectToken += 1
        activeStarBirthEffect = StarBirthEffectState(
            constellationId: constellation.id,
            starId: star.id,
            connectionPairs: birthConnectionPairs(constellation: constellation, discoveredCount: discoveredCount, newStarId: star.id),
            token: spawnEffectToken
        )
        return birthEffectDuration()
    }

    private func birthEffectDuration() -> TimeInterval {
        if accessibility.isReduceMotionEnabled {
            return livePresentationState.isTutorialClock ? 0.35 : 0.42
        }
        return livePresentationState.isTutorialClock ? 1.2 : 1.5
    }

    private func birthConnectionPairs(constellation: Constellation, discoveredCount: Int, newStarId: UUID) -> [StarBirthConnectionPair] {
        let presentation = focusSessionPresentation(for: constellation)
        let discoveredIds = Set(presentation.stars(forDiscoveredCount: discoveredCount).map(\.id))
        return constellation.edges.compactMap { edge in
            let isConnectedToNew = edge.from == newStarId || edge.to == newStarId
            guard isConnectedToNew, discoveredIds.contains(edge.from), discoveredIds.contains(edge.to) else { return nil }
            return StarBirthConnectionPair(fromStarId: edge.from, toStarId: edge.to)
        }
    }

    private func runningEdgeIndices(constellation: Constellation, discoveredCount: Int) -> Set<Int> {
        renderModel.runningEdgeIndices(
            constellation: constellation,
            discoveredCount: discoveredCount,
            renderMetadata: renderMetadataById(constellation.id)
        )
    }

    private func scheduleVisibleEdgeReveal(constellationId: UUID, discoveredCount: Int, after delay: TimeInterval) {
        Task { @MainActor in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            skyState.setVisibleDiscoveredCount(discoveredCount, for: constellationId)
        }
    }

    private func beginEdgeRevealAnimation(constellation: Constellation, discoveredCount: Int, duration: TimeInterval) {
        let id = constellation.id
        var state = skyState.edgeRevealStates[id] ?? MySkyEdgeRevealState()
        state.pendingDiscoveredCount = discoveredCount
        state.progress = duration > 0 ? 0 : 1
        skyState.setEdgeRevealState(state, for: id)

        let token = (edgeRevealTokens[id] ?? 0) + 1
        edgeRevealTokens[id] = token

        if duration > 0 {
            withAnimation(.linear(duration: duration)) {
                var updated = skyState.edgeRevealStates[id] ?? MySkyEdgeRevealState()
                updated.progress = 1
                skyState.setEdgeRevealState(updated, for: id)
            }
        }

        Task { @MainActor in
            if duration > 0 { try? await Task.sleep(for: .seconds(duration)) }
            guard edgeRevealTokens[id] == token else { return }
            guard var latest = skyState.edgeRevealStates[id] else { return }
            latest.committedDiscoveredCount = discoveredCount
            latest.pendingDiscoveredCount = nil
            latest.progress = 0
            skyState.setEdgeRevealState(latest, for: id)
        }
    }

    private func edgeRenderState(for constellation: Constellation) -> (visibleIndices: Set<Int>, visibilityOverrides: [Int: CGFloat]) {
        renderModel.edgeRenderState(
            for: constellation,
            edgeRevealStates: skyState.edgeRevealStates,
            renderMetadata: renderMetadataById(constellation.id)
        )
    }

    private var tutorialWarpCanAdvance: Bool {
        guard sessionStore.currentStatus() == .running else { return false }
        guard activeStarBirthEffect == nil else { return false }
        guard completionFlowTask == nil else { return false }
        return livePresentationState.isAwaitingBirth
    }

    private func coordinateMapper(for size: CGSize) -> MySkyCoordinateMapper {
        MySkyCoordinateMapper(canvasSize: size)
    }

    private func cameraController(for size: CGSize) -> MySkyCameraController {
        MySkyCameraController(mapper: coordinateMapper(for: size))
    }

    @ViewBuilder
        private func skyCanvas(size: CGSize, animationTime: TimeInterval?) -> some View {
            let mapper = coordinateMapper(for: size)

            ZStack(alignment: .topLeading) {
                settledConstellationLayer(mapper: mapper, animationTime: animationTime)
                dailyRewardLayer(mapper: mapper, animationTime: animationTime)
                liveSessionLayer(mapper: mapper, animationTime: animationTime)
            }
            .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func settledConstellationLayer(mapper: MySkyCoordinateMapper, animationTime: TimeInterval?) -> some View {
        let settledItems = renderModel.settledItems(
            completedSessions: sessionStore.completedSessions,
            skyState: skyState,
            completionConstellationId: completionConstellation?.id,
            liveConstellationId: livePresentationState.constellationId
        )

        if !settledItems.isEmpty {
            SettledConstellationsCanvas(
                items: settledItems,
                coordinateMapper: mapper,
                camera: cameraState,
                starStyle: starStyle,
                reduceMotion: accessibility.isReduceMotionEnabled,
                highPerformanceMode: highPerformanceMode,
                isInteracting: isInteracting,
                animationTime: animationTime
            )
        }
    }

    @ViewBuilder
    private func dailyRewardLayer(mapper: MySkyCoordinateMapper, animationTime: TimeInterval?) -> some View {
        if !dailyRewardStore.stars.isEmpty {
            DailyRewardsCanvas(
                stars: dailyRewardStore.stars,
                coordinateMapper: mapper,
                camera: cameraState,
                reduceMotion: accessibility.isReduceMotionEnabled,
                isInteracting: isInteracting,
                animationTime: animationTime
            )
        }

        if let selectedDailyStar = dailyRewardStore.selectedStar {
            let screenPoint = mapper.screenPoint(fromSky: selectedDailyStar.position, camera: cameraState)
            VStack(spacing: 4) {
                Text("✨ 일일 세션 완료")
                    .font(.caption2.bold())
                    .foregroundStyle(.yellow)
                Text(selectedDailyStar.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .position(x: screenPoint.x, y: screenPoint.y - 50)
            .zIndex(100)
            .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func liveSessionLayer(mapper: MySkyCoordinateMapper, animationTime: TimeInterval?) -> some View {
        if let liveConstellationId = livePresentationState.constellationId,
           let constellation = constellationById(liveConstellationId) {
            let edgeState = edgeRenderState(for: constellation)
            let presentation = focusSessionPresentation(for: constellation)
            let hasBirthEffect = activeStarBirthEffect?.constellationId == constellation.id

            ConstellationRenderer(
                constellation: constellation,
                coordinateMapper: mapper,
                camera: cameraState,
                discoveredStarCount: presentation.committedDiscoveredCount,
                showEdges: true,
                edgeProgress: 1,
                reduceMotion: accessibility.isReduceMotionEnabled,
                highPerformanceMode: highPerformanceMode,
                renderMetadata: renderMetadataById(constellation.id),
                discoveredStarIndices: presentation.discoveredStarIndices,
                visibleEdgeIndices: edgeState.visibleIndices,
                edgeVisibilityOverrides: edgeState.visibilityOverrides,
                starStyle: starStyle,
                activeBirthEffect: hasBirthEffect ? activeStarBirthEffect : nil,
                animationTime: animationTime
            )
        }
    }

    @ViewBuilder
    private func interactiveEffectLayer(size: CGSize) -> some View {
        let mapper = coordinateMapper(for: size)
        if let rewardCenter = effectsCoordinator.dailyStarRippleCenter {
            RippleEffectView(
                position: mapper.screenPoint(fromSky: rewardCenter, camera: cameraState),
                reduceMotion: accessibility.isReduceMotionEnabled
            )
            .id("daily-ripple-\(effectsCoordinator.dailyRewardEffectToken)")
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func blackHoleVisualLayer(size: CGSize) -> some View {
        ZStack {
            Color.black
                .opacity(blackHoleBackgroundOpacity)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.30), value: blackHoleBackgroundOpacity)

            if blackHoleCoordinator.showsAbsorptionCanvas {
                BlackHoleAbsorptionCanvas(
                    center: blackHoleCoordinator.overlay.center,
                    phase: blackHoleCoordinator.phase,
                    absorption: blackHoleCoordinator.absorption
                )
                .frame(width: size.width, height: size.height)
            }

            if blackHoleCoordinator.showsSingularityOverlay {
                BlackHoleOverlayView(overlay: blackHoleCoordinator.overlay)
                    .frame(width: size.width, height: size.height)
            }

            if blackHoleCoordinator.phase == .whiteFlash {
                Color.black
                    .opacity(blackHoleCoordinator.whiteFlashOpacity)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            if blackHoleCoordinator.isAwaitingUserInputToReturn {
                VStack(spacing: 8) {
                    Spacer()
                    Text("화면을 탭하면 원래 하늘로 돌아갑니다")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.black.opacity(0.45), in: Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .padding(.bottom, 132)
                }
                .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture {
            guard blackHoleCoordinator.isAwaitingUserInputToReturn else { return }
            blackHoleCoordinator.beginReturnToSky(reduceMotion: accessibility.isReduceMotionEnabled)
        }
        .allowsHitTesting(blackHoleCoordinator.isAwaitingUserInputToReturn)
    }

    private func handleBlackHolePhaseChange(
        from oldValue: MySkyBlackHoleCoordinator.Phase,
        to newValue: MySkyBlackHoleCoordinator.Phase
    ) {
        switch newValue {
        case .stage4 where oldValue != .stage4:
            Haptics.light()
        case .stage7Spawning where oldValue != .stage7Spawning:
            if blackHolePrePresentationCamera == nil {
                blackHolePrePresentationCamera = cameraState
            }
            animateCamera(
                to: MySkyCameraState(centerSky: MySkyCameraState.default.centerSky, zoom: blackHolePresentationZoom),
                duration: accessibility.isReduceMotionEnabled ? 0.55 : 1.2
            )
            Haptics.warning()
        case .stage7AwaitingInput where oldValue != .stage7AwaitingInput:
            Haptics.light()
        case .stage8Collapsing where oldValue != .stage8Collapsing:
            animateCamera(
                to: MySkyCameraState(
                    centerSky: MySkyCameraState.default.centerSky,
                    zoom: max(0.12, blackHolePresentationZoom * 0.55)
                ),
                duration: accessibility.isReduceMotionEnabled ? 0.35 : 0.70
            )
            Haptics.warning()
        case .blackout where oldValue != .blackout:
            Haptics.light()
        case .whiteFlash where oldValue != .whiteFlash:
            Haptics.light()
        case .cooldown where oldValue != .cooldown:
            dragStartCamera = nil
            magnifyStartZoom = nil
            isInteracting = false
            inputProtectionCoordinator.reset()
            interactionController.prepareForNextProtectionActivation()
        case .idle where oldValue != .idle:
            if oldValue == .blackout || oldValue == .whiteFlash || oldValue == .stage8Collapsing {
                let restoreCamera = blackHolePrePresentationCamera ?? .default
                animateCamera(
                    to: restoreCamera,
                    duration: accessibility.isReduceMotionEnabled ? 0.45 : 0.85
                )
            }
            dragStartCamera = nil
            magnifyStartZoom = nil
            isInteracting = false
            inputProtectionCoordinator.reset()
            interactionController.prepareForNextProtectionActivation()
            inputProtectionCoordinator.resetActivationProgress()
            blackHolePrePresentationCamera = nil
        default:
            break
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
                
                // Keep local daily reward stars authoritative.
                // Remote fetched stars should not overwrite locally persisted reward positions.

                let mergedSky = stateMerger.mergeRemoteSkyWithLocalState(sky)
                skyState.replace(snapshot: mergedSky)
                sessionStore.replaceCompletedSessions(mergedSky.completedSessions)
            } catch {
                Self.logger.error("sky fetch failed: \(error.localizedDescription)")
            }
        }
    
    private var localConstellationUserId: String {
        userId.isEmpty ? fallbackLocalUserId : userId
    }

    private func rebuildRemoteFocusLayout() {
        let layout = viewModel.layoutFocusConstellations(skyState.remoteFocusLayoutItems, userSeed: Int64(userSeed))
        applyRemoteFocusLayout(layout)
    }

    private func applyRemoteFocusLayout(_ layout: [FocusSkyLayoutResult]) {
        let merged = stateMerger.mergeLayout(layout)
        skyState.replaceRemoteLayoutItems(layout.map(\.item))
        skyState.replaceMergedWorld(
            constellations: merged.constellations,
            completedSessions: merged.completedSessions
        )
        sessionStore.replaceCompletedSessions(merged.completedSessions)
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
            // Keep the just-completed constellation stable on screen.
            // Re-fetching and re-laying out immediately after memo save can remap
            // completed sessions and cause a visible position jump.
            return true
        } catch {
            Self.logger.error("focus save failed: \(error.localizedDescription)")
            return false
        }
    }
}
