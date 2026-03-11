// 📂 Features/Session/ViewModels/DailySessionViewModel.swift
import SwiftUI
import Combine

@MainActor
final class DailySessionViewModel: ObservableObject {
    @Published var templates: [ChecklistTemplate] = []
    @Published var activeItems: [ChecklistItem] = []
    @Published var isSessionActive: Bool = false
    @Published var showCompletionAlert: Bool = false
    @Published var expandedTemplateID: UUID? = nil
    
    @Published var fetchedSessions: [FetchedDailySession] = []
    @Published var isFetchingHistory: Bool = false
    
    private let templatesKey = "Focustella_ChecklistTemplates"
    private let activeSessionKey = "Focustella_ActiveSessionItems"
    private let currentUserUUID = "dummy-user-uuid-1234"
    
    init() {
        loadTemplates()
        loadActiveSession()
    }
    
    // MARK: - Templates 로직
    func loadTemplates() {
        if let data = UserDefaults.standard.data(forKey: templatesKey),
           let decoded = try? JSONDecoder().decode([ChecklistTemplate].self, from: data) {
            self.templates = decoded
        } else {
            self.templates = []
        }
    }
    
    func saveTemplates() {
        if let encoded = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(encoded, forKey: templatesKey)
        }
    }
    func addTemplate(_ template: ChecklistTemplate) {
        templates.append(template)
        saveTemplates()
    }
    func updateTemplate(_ updatedTemplate: ChecklistTemplate) {
        if let index = templates.firstIndex(where: { $0.id == updatedTemplate.id }) {
            templates[index] = updatedTemplate
            saveTemplates()
        }
    }
    func deleteTemplate(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        saveTemplates()
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
    }
    
    func cancelSession() {
        clearActiveSession()
    }
    
    func startEmptySession() {
        self.activeItems = []
        self.isSessionActive = true
        self.expandedTemplateID = nil
        saveActiveSession()
    }
    
    func startSession(with template: ChecklistTemplate) {
        activeItems = template.items.map { var item = $0; item.isCompleted = false; return item }
        isSessionActive = true
        expandedTemplateID = nil
        saveActiveSession()
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
        
        let newItem = ChecklistItem(title: trimmedTitle)
        activeItems.append(newItem)
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
    
    func completeDailySession() async {
        // 🗑️ 기존 String 인코딩 걷어내기
        // guard let itemsData = try? JSONEncoder().encode(activeItems)... (삭제)
        
        // 🔥 깔끔해진 페이로드 생성
        let payload = DailySessionSaveRequest(
            timestamp: Date().logicalDayStart.ISO8601Format(),
            items: activeItems // 배열을 그대로 넘깁니다!
        )
        
        guard let url = URL(string: "http://localhost:8080/api/v1/session/daily") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(currentUserUUID, forHTTPHeaderField: "X-User-ID")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            // Swift의 JSONEncoder가 payload 내부의 items 배열까지 한 번에 예쁜 JSON으로 만들어 줍니다.
            request.httpBody = try JSONEncoder().encode(payload)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("✅ 서버 저장 성공!")
                self.showCompletionAlert = true
                self.clearActiveSession()
            }
            // ... 에러 처리 생략
        } catch {
            print("❌ 요청 실패: \(error.localizedDescription)")
        }
    }
    
    func fetchSessionHistory() async {
        self.isFetchingHistory = true
        guard let url = URL(string: "http://localhost:8080/api/v1/session/daily?userId=\(currentUserUUID)") else {
            self.isFetchingHistory = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let jsonString = String(data: data, encoding: .utf8) {
                    print("🌐 서버 응답 데이터: \(jsonString)")
                }
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                let decoded = try JSONDecoder().decode([FetchedDailySession].self, from: data)
                self.fetchedSessions = decoded
                print("✅ 기록 불러오기 성공! (\(decoded.count)건)")
            } else {
                print("❌ 조회 실패: 상태 코드 \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            print("❌ 데이터 조회 네트워크 오류: \(error.localizedDescription)")
        }
        self.isFetchingHistory = false
    }
}
