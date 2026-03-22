// 📂 Features/Session/ViewModels/ActiveSessionViewModel.swift
import SwiftUI
import Combine
import UserNotifications

@MainActor
final class ActiveSessionViewModel: ObservableObject {
    private let saveDailySessionUseCase: SaveDailySessionUseCase

    @Published var activeItems: [ChecklistItem] = []
    @Published var isSessionActive: Bool = false
    @Published var showCompletionAlert: Bool = false
    @Published var hasCompletedToday: Bool = false
    
    private let activeSessionKey = "Focustella_ActiveSessionItems"
    private let lastCompletedDateKey = "Focustella_LastCompletedDate"
    private let activeSessionStartDateKey = "Focustella_ActiveSessionStartDate"
    
    // 편의 이니셜라이저 (DI - 의존성 주입)
    init(saveDailySessionUseCase: SaveDailySessionUseCase = SaveDailySessionUseCase(repository: DailySessionRepositoryImpl())) {
        self.saveDailySessionUseCase = saveDailySessionUseCase
        requestNotificationPermission()
        loadActiveSession()
        refreshTodayStatus()
    }
    
    // MARK: - 1일 1회 및 자동 완료 로직
    func refreshTodayStatus() {
        let today = Date().logicalDateString
        let lastCompleted = UserDefaults.standard.string(forKey: lastCompletedDateKey) ?? ""
        let isDeveloperMode = UserDefaults.standard.bool(forKey: "developerMode")
        
        self.hasCompletedToday = !isDeveloperMode && (today == lastCompleted)
        checkAndResolveExpiredSession()
    }
    
    private func checkAndResolveExpiredSession() {
        guard isSessionActive else { return }
        
        let savedSessionDate = UserDefaults.standard.string(forKey: activeSessionStartDateKey) ?? ""
        let today = Date().logicalDateString
        
        if !savedSessionDate.isEmpty && savedSessionDate != today {
            print("🕒 06시가 지나 만료된 세션을 발견했습니다. 자동 전송을 시작합니다.")
            let isSuccess = self.canComplete
            
            Task {
                await completeDailySession(isAuto: true)
                let title = isSuccess ? "어제의 세션을 성공했어요! 🎉" : "어제의 세션을 아쉽게 실패했어요. 🥲"
                sendLocalNotification(title: "일일 세션 자동 종료", body: title)
                self.clearActiveSession()
            }
        }
    }
    
    // MARK: - Active Session 로직
    private func loadActiveSession() {
        if let data = UserDefaults.standard.data(forKey: activeSessionKey),
           let decoded = try? JSONDecoder().decode([ChecklistItem].self, from: data),
           !decoded.isEmpty {
            self.activeItems = decoded
            self.isSessionActive = true
        }
    }
    
    private func saveActiveSession() {
        if let encoded = try? JSONEncoder().encode(activeItems) {
            UserDefaults.standard.set(encoded, forKey: activeSessionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeSessionKey)
        }
    }
    
    func clearActiveSession() {
        self.activeItems.removeAll()
        self.isSessionActive = false
        UserDefaults.standard.removeObject(forKey: activeSessionKey)
        UserDefaults.standard.removeObject(forKey: activeSessionStartDateKey)
    }
    
    func cancelSession() {
        clearActiveSession()
    }
    
    func startEmptySession() {
        self.activeItems = []
        self.isSessionActive = true
        saveActiveSession()
        UserDefaults.standard.set(Date().logicalDateString, forKey: activeSessionStartDateKey)
    }
    
    func startSession(with template: ChecklistTemplate) {
        activeItems = template.items.map { var item = $0; item.isCompleted = false; return item }
        isSessionActive = true
        saveActiveSession()
        UserDefaults.standard.set(Date().logicalDateString, forKey: activeSessionStartDateKey)
    }
    
    func toggleItem(id: UUID) {
        if let index = activeItems.firstIndex(where: { $0.id == id }) {
            activeItems[index].isCompleted.toggle()
            saveActiveSession()
        }
    }
    
    func addActiveItem(title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        activeItems.append(ChecklistItem(title: trimmedTitle))
        saveActiveSession()
    }
    
    func removeActiveItem(at offsets: IndexSet) {
        activeItems.remove(atOffsets: offsets)
        saveActiveSession()
    }
    
    var progress: Double {
        guard !activeItems.isEmpty else { return 0 }
        let completed = activeItems.filter { $0.isCompleted }.count
        return Double(completed) / Double(activeItems.count)
    }
    
    var canComplete: Bool {
        !activeItems.isEmpty && activeItems.allSatisfy { $0.isCompleted }
    }
    
    // MARK: - Server 통신 로직
    func completeDailySession(isAuto: Bool = false) async {
        let payload = DailySessionSaveRequest(
            timestamp: Date().ISO8601Format(),
            checklists: activeItems
        )

        do {
            try await saveDailySessionUseCase.execute(payload)

            await MainActor.run {
                UserDefaults.standard.set(Date().logicalDateString, forKey: self.lastCompletedDateKey)
                self.refreshTodayStatus()

                if !isAuto {
                    self.showCompletionAlert = true
                    
                    // 🔥 2.5초 뒤 스르륵 템플릿 화면으로 돌아가기
                    Task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        await MainActor.run {
                            self.clearActiveSession()
                            self.showCompletionAlert = false
                        }
                    }
                } else {
                    self.clearActiveSession()
                }
            }
        } catch {
            print("❌ 요청 실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notification
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("알림 권한 승인 여부: \(granted)")
        }
    }
    
    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
