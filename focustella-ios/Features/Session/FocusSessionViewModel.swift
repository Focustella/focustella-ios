import Foundation
import Combine

@MainActor
final class FocusSessionViewModel: ObservableObject {
    enum State: String {
        case idle
        case running
        case paused
        case completed
    }

    @Published var targetMinutes: Int = 25
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var state: State = .idle
    @Published private(set) var records: [FocusSessionRecord] = []

    private let store: SessionStore
    private var timer: Timer?
    private var startedAt: Date?

    init(store: SessionStore) {
        self.store = store
        self.records = store.focusRecords
    }

    convenience init() {
        self.init(store: .shared)
    }

    func start() {
        if state == .completed {
            reset()
        }
        guard state == .idle else { return }
        startedAt = Date()
        elapsedSeconds = 0
        state = .running
        startTimer()
    }

    func pause() {
        guard state == .running else { return }
        stopTimer()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        startTimer()
    }

    func stop() {
        guard state == .running || state == .paused else { return }
        stopTimer()
        let end = Date()
        let start = startedAt ?? end
        store.addFocusRecord(
            startedAt: start,
            endedAt: end,
            targetMinutes: targetMinutes,
            actualSeconds: elapsedSeconds
        )
        records = store.focusRecords
        state = .completed
    }

    func reset() {
        stopTimer()
        startedAt = nil
        elapsedSeconds = 0
        state = .idle
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedSeconds += 1
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
