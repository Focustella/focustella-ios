import Foundation
import Combine

@MainActor
final class MemoSheetViewModel: ObservableObject {
    private let fetchFocusTagsUseCase: FetchFocusTagsUseCase
    private let addFocusTagUseCase: AddFocusTagUseCase
    private let deleteFocusTagUseCase: DeleteFocusTagUseCase

    @Published private(set) var tags: [String] = []
    @Published var isLoadingTags = false

    init(
        fetchFocusTagsUseCase: FetchFocusTagsUseCase,
        addFocusTagUseCase: AddFocusTagUseCase,
        deleteFocusTagUseCase: DeleteFocusTagUseCase
    ) {
        self.fetchFocusTagsUseCase = fetchFocusTagsUseCase
        self.addFocusTagUseCase = addFocusTagUseCase
        self.deleteFocusTagUseCase = deleteFocusTagUseCase
    }

    convenience init() {
        let repository = FocusTagRepositoryImpl()
        self.init(
            fetchFocusTagsUseCase: FetchFocusTagsUseCase(repository: repository),
            addFocusTagUseCase: AddFocusTagUseCase(repository: repository),
            deleteFocusTagUseCase: DeleteFocusTagUseCase(repository: repository)
        )
    }

    func loadTagsIfNeeded() async {
        guard tags.isEmpty else { return }
        isLoadingTags = true
        defer { isLoadingTags = false }

        do {
            tags = try await fetchFocusTagsUseCase.execute()
                .map(\.name)
                .sorted()
        } catch {
            print("🚨 [태그 조회 실패] \(error.localizedDescription)")
        }
    }

    func addTag(name: String) async -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        do {
            let created = try await addFocusTagUseCase.execute(name: trimmed)
            if !tags.contains(created.name) {
                tags.append(created.name)
                tags.sort()
            }
            return created.name
        } catch {
            print("🚨 [태그 추가 실패] \(error.localizedDescription)")
            return nil
        }
    }

    func deleteTag(_ tag: String) async {
        do {
            try await deleteFocusTagUseCase.execute(name: tag)
            tags.removeAll { $0 == tag }
        } catch {
            print("🚨 [태그 삭제 실패] \(error.localizedDescription)")
        }
    }
}
