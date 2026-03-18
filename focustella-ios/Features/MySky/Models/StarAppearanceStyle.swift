// 📂 StarAppearanceStyle.swift (새로 만들거나 앱 전역에서 접근 가능한 곳에 추가)

import Foundation

public enum StarAppearanceStyle: String, CaseIterable, Codable {
    case realistic = "우주적 리얼 (원형)"
    case fourPoint = "우아한 4각"
    case fivePoint = "클래식 5각"
    case eightPoint = "눈꽃 8각"
}
