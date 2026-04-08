import Foundation

struct SessionFeatureDependencies {
    let makeActiveSessionViewModel: () -> ActiveSessionViewModel
    let makeTemplateViewModel: () -> TemplateViewModel
    let makeSessionHistoryViewModel: () -> SessionHistoryViewModel

    static let live = SessionFeatureDependencies(
        makeActiveSessionViewModel: {
            ActiveSessionViewModel(
                saveDailySessionUseCase: SaveDailySessionUseCase(
                    repository: DailySessionRepositoryImpl()
                )
            )
        },
        makeTemplateViewModel: {
            TemplateViewModel()
        },
        makeSessionHistoryViewModel: {
            SessionHistoryViewModel(
                fetchDailySessionsUseCase: FetchDailySessionsUseCase(
                    repository: DailySessionRepositoryImpl()
                )
            )
        }
    )
}
