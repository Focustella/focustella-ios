import Foundation
import Combine

@MainActor
final class MySkyViewModel: ObservableObject {
    private let fetchMySkyUseCase: FetchMySkyUseCase
    private let createFocusSessionUseCase: CreateFocusSessionUseCase
    private let saveFocusSessionUseCase: SaveFocusSessionUseCase
    private let constellationRepository: ConstellationRepository
    private let updateNicknameUseCase = UpdateNicknameUseCase()

    init(
        fetchMySkyUseCase: FetchMySkyUseCase,
        createFocusSessionUseCase: CreateFocusSessionUseCase,
        saveFocusSessionUseCase: SaveFocusSessionUseCase,
        constellationRepository: ConstellationRepository
    ) {
        self.fetchMySkyUseCase = fetchMySkyUseCase
        self.createFocusSessionUseCase = createFocusSessionUseCase
        self.saveFocusSessionUseCase = saveFocusSessionUseCase
        self.constellationRepository = constellationRepository
    }

    convenience init() {
        let skyRepository = SkyRepositoryImpl()
        let focusRepository = FocusSessionRepositoryImpl()
        self.init(
            fetchMySkyUseCase: FetchMySkyUseCase(repository: skyRepository),
            createFocusSessionUseCase: CreateFocusSessionUseCase(repository: focusRepository),
            saveFocusSessionUseCase: SaveFocusSessionUseCase(repository: focusRepository),
            constellationRepository: ConstellationRepository()
        )
    }

    func fetchMySky(userSeed: Int64) async throws -> MySkySnapshot {
        let sky = try await fetchMySkyUseCase.execute()
        let remoteFocusLayoutItems = sky.focusConstellations.compactMap(makeRemoteFocusLayoutItem)
        let layout = layoutFocusConstellations(remoteFocusLayoutItems, userSeed: userSeed)

        return MySkySnapshot(
            seed: sky.seed,
            dailyStars: SkyMapper.mapDailyStars(seed: sky.seed, dailyStars: sky.dailyStars),
            remoteFocusLayoutItems: remoteFocusLayoutItems,
            completedSessions: layout.map(\.session),
            constellations: deduplicatedConstellations(layout.map(\.constellation))
        )
    }

    func createFocusSession(durationMinutes: Int) async throws -> FocusSessionCreateResponseDTO {
        try await createFocusSessionUseCase.execute(durationMinutes: durationMinutes)
    }

    func makeCreatedFocusLayoutItem(
        _ response: FocusSessionCreateResponseDTO,
        startedAt: Date,
        slotSeconds: Int
    ) -> FocusSkyLayoutItem {
        FocusSkyLayoutItem(
            sessionId: response.focusSessionId,
            serverConstellationId: response.constellationId,
            template: response.constellation,
            startedAt: startedAt,
            endedAt: nil,
            slotSeconds: slotSeconds,
            discoveredStarCount: 0,
            status: .running,
            memo: nil
        )
    }

    func layoutFocusConstellations(_ items: [FocusSkyLayoutItem], userSeed: Int64) -> [FocusSkyLayoutResult] {
        var constellations: [Constellation] = []
        var results: [FocusSkyLayoutResult] = []

        for item in items.sorted(by: { focusLayoutOrder(lhs: $0, rhs: $1) }) {
            guard let result = placeFocusLayoutItem(item, occupied: constellations, userSeed: userSeed) else {
                continue
            }

            constellations.append(result.constellation)
            results.append(result)
        }

        return results
    }

    func placeFocusLayoutItem(
        _ item: FocusSkyLayoutItem,
        occupied: [Constellation],
        userSeed: Int64
    ) -> FocusSkyLayoutResult? {
        guard let constellation = constellationRepository.placeRemoteConstellation(
            template: item.template,
            placementKey: item.sessionId,
            occupied: occupied,
            randomSeed: userSeed
        ) else {
            return nil
        }

        let session = FocusSession(
            id: SkyMapper.focusSessionId(item.sessionId),
            serverSessionId: item.sessionId,
            serverConstellationId: item.serverConstellationId,
            startedAt: item.startedAt,
            endedAt: item.endedAt,
            slotSeconds: item.slotSeconds,
            constellationId: constellation.id,
            discoveredStarCount: item.discoveredStarCount,
            status: item.status,
            memo: item.memo
        )

        return FocusSkyLayoutResult(item: item, session: session, constellation: constellation)
    }

    func saveCompletedSession(_ request: FocusSessionSaveRequestDTO) async throws {
        try await saveFocusSessionUseCase.execute(request)
    }

    private func makeRemoteFocusLayoutItem(from record: FocusSessionRecordDTO) -> FocusSkyLayoutItem? {
        guard
            let startedAt = SkyMapper.parseISO8601Date(record.startedAt),
            let endedAt = SkyMapper.parseISO8601Date(record.endedAt)
        else {
            return nil
        }

        return FocusSkyLayoutItem(
            sessionId: record.sessionId,
            serverConstellationId: record.constellationId,
            template: record.constellation,
            startedAt: startedAt,
            endedAt: endedAt,
            slotSeconds: record.slotSeconds,
            discoveredStarCount: record.discoveredStarCount,
            status: .completed,
            memo: SessionMemo(
                topicTags: record.topicTags,
                rating: record.rating,
                freeText: record.freeText
            )
        )
    }

    private func deduplicatedConstellations(_ constellations: [Constellation]) -> [Constellation] {
        var seen: Set<UUID> = []
        var result: [Constellation] = []

        for constellation in constellations where seen.insert(constellation.id).inserted {
            result.append(constellation)
        }

        return result
    }

    private func focusLayoutOrder(lhs: FocusSkyLayoutItem, rhs: FocusSkyLayoutItem) -> Bool {
        if lhs.startedAt != rhs.startedAt {
            return lhs.startedAt < rhs.startedAt
        }
        return lhs.sessionId < rhs.sessionId
    }
    
    func saveNickname(_ nickname: String) async -> Bool {
            do {
                try await updateNicknameUseCase.execute(nickname: nickname)
                                // 🔥 2. AuthSessionStore를 통해 안전하게 닉네임 업데이트!
                AuthSessionStore.updateNickname(nickname)
                
                print("✅ 닉네임 저장 및 튜토리얼 완료 처리 성공! 닉네임: \(nickname)")
                return true
                
            } catch {
                print("❌ 닉네임 저장 실패: \(error.localizedDescription)")
                return false
            }
        }
}
