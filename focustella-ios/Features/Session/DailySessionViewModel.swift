import SwiftUI
import Combine

// MARK: - Models
struct ChecklistItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
}

struct ChecklistTemplate: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var items: [ChecklistItem]
}

// 기존 DailySessionPayload 대신 사용합니다.
struct DailySessionSaveRequest: Codable {
    let timestamp: String
    let checklists: String
}

extension Date {
    var logicalDayStart: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: self)
        
        if let hour = components.hour, hour < 6 {
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: self))!.addingTimeInterval(6 * 3600)
        } else {
            return calendar.startOfDay(for: self).addingTimeInterval(6 * 3600)
        }
    }
}

// MARK: - ViewModel
@MainActor
final class DailySessionViewModel: ObservableObject {
    @Published var templates: [ChecklistTemplate] = []
    @Published var activeItems: [ChecklistItem] = []
    @Published var isSessionActive: Bool = false
    @Published var showCompletionAlert: Bool = false
    
    // 🔥 아코디언 UI를 위해 현재 펼쳐진 템플릿의 ID를 저장
    @Published var expandedTemplateID: UUID? = nil
    
    private let templatesKey = "Focustella_ChecklistTemplates"
    private let activeSessionKey = "Focustella_ActiveSessionItems"
    private let currentUserUUID = UUID().uuidString
    
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
            self.templates = [
                ChecklistTemplate(name: "기본 개발 학습", items: [
                    ChecklistItem(title: "알고리즘 1문제 풀기"),
                    ChecklistItem(title: "Spring Boot 개념 복습"),
                    ChecklistItem(title: "SwiftUI UI 구성하기")
                ])
            ]
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
    
    // 🔥 템플릿 수정 로직 추가
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
    
    // MARK: - 진행 중인 세션에 항목 추가
        func addActiveItem(title: String) {
            let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
            guard !trimmedTitle.isEmpty else { return }
            
            let newItem = ChecklistItem(title: trimmedTitle)
            activeItems.append(newItem)
            saveActiveSession() // 변경된 상태를 바로 UserDefaults에 저장
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
    
    func startSession(with template: ChecklistTemplate) {
        activeItems = template.items.map { var item = $0; item.isCompleted = false; return item }
        isSessionActive = true
        expandedTemplateID = nil // 세션 시작 시 펼쳐진 상태 초기화
        saveActiveSession()
    }
    
    func toggleItem(id: UUID) {
        if let index = activeItems.firstIndex(where: { $0.id == id }) {
            activeItems[index].isCompleted.toggle()
            saveActiveSession()
        }
    }
    
    var progress: Double {
        guard !activeItems.isEmpty else { return 0 }
        let completed = activeItems.filter { $0.isCompleted }.count
        return Double(completed) / Double(activeItems.count)
    }
    
    var canComplete: Bool {
        !activeItems.isEmpty && activeItems.allSatisfy { $0.isCompleted }
    }
    
    // MARK: - Server 통신
    func completeDailySession() async {
        // 1. 체크리스트 배열을 JSON 문자열로 인코딩
        guard let itemsData = try? JSONEncoder().encode(activeItems),
              let checklistsString = String(data: itemsData, encoding: .utf8) else {
            print("데이터 인코딩 실패")
            return
        }
        
        // 2. 서버가 기대하는 DTO 구조로 페이로드 생성
        let payload = DailySessionSaveRequest(
            timestamp: Date().logicalDayStart.ISO8601Format(),
            checklists: checklistsString
        )
        
        // 3. 서버 URL 설정 (시뮬레이터 기준. 실기기는 맥북의 IP 주소로 변경)
        guard let url = URL(string: "http://localhost:8080/api/v1/session/daily") else {
            print("유효하지 않은 URL")
            return
        }
        
        // 4. URLRequest 구성 (POST 메서드 및 헤더 설정)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 5. 네트워크 통신 실행
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    print("✅ 서버 저장 성공!")
                    // 성공 시 UI 상태 업데이트
                    self.showCompletionAlert = true
                    self.clearActiveSession()
                } else {
                    print("❌ 서버 에러: 상태 코드 \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("에러 응답 내용: \(errorString)")
                    }
                }
            }
        } catch {
            print("❌ 네트워크 요청 실패: \(error.localizedDescription)")
            // 통신 실패 시 사용자에게 알리거나 오프라인 저장을 하는 예외 처리를 추가할 수 있습니다.
        }
    }
}
