// 📂 Features/Session/ViewModels/DailySessionViewModel.swift
import SwiftUI
import Combine
import UserNotifications

@MainActor
final class DailySessionViewModel: ObservableObject {
    private let saveDailySessionUseCase: SaveDailySessionUseCase
    private let fetchDailySessionsUseCase: FetchDailySessionsUseCase

    @Published var templates: [ChecklistTemplate] = []
    @Published var activeItems: [ChecklistItem] = []
    @Published var isSessionActive: Bool = false
    @Published var showCompletionAlert: Bool = false
    @Published var expandedTemplateID: UUID? = nil
    
    @Published var fetchedSessions: [FetchedDailySession] = []
    @Published var isFetchingHistory: Bool = false
    
    // 🔥 오늘 이미 완료했는지 여부 (View에서 사용)
    @Published var hasCompletedToday: Bool = false
    
    private let templatesKey = "Focustella_ChecklistTemplates"
    private let activeSessionKey = "Focustella_ActiveSessionItems"
    
    // 상태 저장 키
    private let lastCompletedDateKey = "Focustella_LastCompletedDate"
    private let activeSessionStartDateKey = "Focustella_ActiveSessionStartDate"
    
    init(
        saveDailySessionUseCase: SaveDailySessionUseCase,
        fetchDailySessionsUseCase: FetchDailySessionsUseCase
    ) {
        self.saveDailySessionUseCase = saveDailySessionUseCase
        self.fetchDailySessionsUseCase = fetchDailySessionsUseCase
        requestNotificationPermission()
        loadTemplates()
        loadActiveSession()
        refreshTodayStatus()
    }

    convenience init() {
        let repository = DailySessionRepositoryImpl()
        self.init(
            saveDailySessionUseCase: SaveDailySessionUseCase(repository: repository),
            fetchDailySessionsUseCase: FetchDailySessionsUseCase(repository: repository)
        )
    }
    
    // MARK: - 1일 1회 및 자동 완료 로직
    
    /// 앱이 켜지거나 화면이 나타날 때마다 상태를 점검합니다.
    func refreshTodayStatus() {
        let today = Date().logicalDateString
        let lastCompleted = UserDefaults.standard.string(forKey: lastCompletedDateKey) ?? ""
        let isDeveloperMode = UserDefaults.standard.bool(forKey: "developerMode")
        
        // 개발자 모드면 무조건 통과, 아니면 오늘 완료 여부 체크
        self.hasCompletedToday = !isDeveloperMode && (today == lastCompleted)
        
        // 06시가 지났는데 아직 켜져있는 세션이 있는지 검사 (Catch-up)
        checkAndResolveExpiredSession()
    }
    
    private func checkAndResolveExpiredSession() {
        guard isSessionActive else { return }
        
        let savedSessionDate = UserDefaults.standard.string(forKey: activeSessionStartDateKey) ?? ""
        let today = Date().logicalDateString
        
        // 세션을 시작한 논리적 날짜와 오늘의 논리적 날짜가 다르다면? = 06시가 지났다!
        if !savedSessionDate.isEmpty && savedSessionDate != today {
            print("🕒 06시가 지나 만료된 세션을 발견했습니다. 자동 전송을 시작합니다.")
            let isSuccess = self.canComplete
            
            Task {
                // 서버에 결과 전송 (isAuto 플래그로 별 애니메이션은 안 띄움)
                await completeDailySession(isAuto: true)
                
                // 사용자에게 늦게나마 결과 알림
                let title = isSuccess ? "어제의 세션을 성공했어요! 🎉" : "어제의 세션을 아쉽게 실패했어요. 🥲"
                sendLocalNotification(title: "일일 세션 자동 종료", body: title)
                
                // 상태 초기화
                self.clearActiveSession()
            }
        }
    }
    
    // MARK: - Active Session 로직
    func loadActiveSession() {
        if let data = UserDefaults.standard.data(forKey: activeSessionKey),
           let decoded = try? JSONDecoder().decode([ChecklistItem].self, from: data),
           !decoded.isEmpty {
            self.activeItems = decoded
            self.isSessionActive = true
        }
    }
    
    func saveActiveSession() {
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
        self.expandedTemplateID = nil
        saveActiveSession()
        UserDefaults.standard.set(Date().logicalDateString, forKey: activeSessionStartDateKey)
    }
    
    func startSession(with template: ChecklistTemplate) {
        activeItems = template.items.map { var item = $0; item.isCompleted = false; return item }
        isSessionActive = true
        expandedTemplateID = nil
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
                }
                self.clearActiveSession()
            }
        } catch {
            print("❌ 요청 실패: \(error.localizedDescription)")
        }
    }
    
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
    
    // MARK: - Templates 로직 (이전과 동일)
    func loadTemplates() {
        if let data = UserDefaults.standard.data(forKey: templatesKey),
           let decoded = try? JSONDecoder().decode([ChecklistTemplate].self, from: data) {
            self.templates = decoded
        }
    }
    func saveTemplates() {
        if let encoded = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(encoded, forKey: templatesKey)
        }
    }
    func addTemplate(_ template: ChecklistTemplate) { templates.append(template); saveTemplates() }
    func updateTemplate(_ updatedTemplate: ChecklistTemplate) {
        if let index = templates.firstIndex(where: { $0.id == updatedTemplate.id }) { templates[index] = updatedTemplate; saveTemplates() }
    }
    func deleteTemplate(at offsets: IndexSet) { templates.remove(atOffsets: offsets); saveTemplates() }
    
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
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // 즉시 발송
        UNUserNotificationCenter.current().add(request)
    }
}
