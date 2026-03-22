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

    func fetchMySky() async throws -> MySkySnapshot {
        let sky = try await fetchMySkyUseCase.execute()
        var constellations: [Constellation] = []
        var completedSessions: [FocusSession] = []

        for record in sky.focusConstellations {
            guard let constellation = constellationRepository.placeRemoteConstellation(
                template: record.constellation,
                placementKey: record.sessionId,
                occupied: constellations
            ) else {
                continue
            }
            guard let session = SkyMapper.mapFocusSession(record, constellationId: constellation.id) else {
                continue
            }
            constellations.append(constellation)
            completedSessions.append(session)
        }

        return MySkySnapshot(
            seed: sky.seed,
            dailyStars: SkyMapper.mapDailyStars(seed: sky.seed, dailyStars: sky.dailyStars),
            completedSessions: completedSessions,
            constellations: deduplicatedConstellations(constellations)
        )
    }

    func createFocusSession(durationMinutes: Int) async throws -> FocusSessionCreateResponseDTO {
        try await createFocusSessionUseCase.execute(durationMinutes: durationMinutes)
    }

    func placeCreatedConstellation(
        _ response: FocusSessionCreateResponseDTO,
        occupied: [Constellation]
    ) -> Constellation? {
        constellationRepository.placeRemoteConstellation(
            template: response.constellation,
            placementKey: response.focusSessionId,
            occupied: occupied
        )
    }

    func saveCompletedSession(_ request: FocusSessionSaveRequestDTO) async throws {
        try await saveFocusSessionUseCase.execute(request)
    }

    private func deduplicatedConstellations(_ constellations: [Constellation]) -> [Constellation] {
        var seen: Set<UUID> = []
        var result: [Constellation] = []

        for constellation in constellations where seen.insert(constellation.id).inserted {
            result.append(constellation)
        }

        return result
    }
    
    func saveNickname(_ nickname: String) async -> Bool {
            do {
                try await updateNicknameUseCase.execute(nickname: nickname)
                
                // 성공했다면 다신 튜토리얼 안 뜨게 UserDefaults 변경!
                UserDefaults.standard.set(false, forKey: "needsTutorial")
                print("✅ 닉네임 저장 및 튜토리얼 완료 처리 성공!")
                return true
                
            } catch {
                print("❌ 닉네임 저장 실패: \(error.localizedDescription)")
                return false
            }
        }
}
