// 📂 Features/Session/ViewModels/SessionHistoryViewModel.swift
import SwiftUI
import Combine

@MainActor
final class SessionHistoryViewModel: ObservableObject {
    private let fetchDailySessionsUseCase: FetchDailySessionsUseCase
    
    @Published var fetchedSessions: [FetchedDailySession] = []
    @Published var isFetchingHistory: Bool = false
    
    init(fetchDailySessionsUseCase: FetchDailySessionsUseCase = FetchDailySessionsUseCase(repository: DailySessionRepositoryImpl())) {
        self.fetchDailySessionsUseCase = fetchDailySessionsUseCase
    }
    
    // MARK: - Server 통신 로직 (히스토리 조회)
    func fetchSessionHistory() async {
        self.isFetchingHistory = true

        do {
            let decoded = try await fetchDailySessionsUseCase.execute()
            await MainActor.run { self.fetchedSessions = decoded }
        } catch {
            print("❌ 데이터 조회 네트워크 오류: \(error.localizedDescription)")
        }
        await MainActor.run { self.isFetchingHistory = false }
    }
}
