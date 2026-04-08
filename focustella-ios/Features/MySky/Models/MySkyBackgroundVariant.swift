import Foundation

enum MySkyBackgroundVariant: String, CaseIterable, Codable {
    case focusStar
    case legacy
    case aurora
    case deepSpace

    var title: String {
        switch self {
        case .focusStar:
            return "포커스 스타"
        case .legacy:
            return "기존 밤하늘"
        case .aurora:
            return "오로라 하늘"
        case .deepSpace:
            return "딥 스페이스"
        }
    }
}
