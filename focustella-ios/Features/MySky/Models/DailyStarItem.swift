// 📂 Features/MySky/Models/DailyStarItem.swift
import Foundation
import CoreGraphics // CGPoint를 사용하기 위해 필요합니다!

struct DailyStarItem: Identifiable, Equatable {
    let id = UUID()
    let position: CGPoint
    let date: Date
}
