import Foundation

enum MySkyBackgroundVariant: String, CaseIterable, Codable {
    case focusStar
    case legacy

    var title: String {
        switch self {
        case .focusStar:
            return "포커스 스타"
        case .legacy:
            return "기존 밤하늘"
        }
    }
}
