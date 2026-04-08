import Foundation
import CoreGraphics
import Combine

@MainActor
final class MySkyDailyRewardStore: ObservableObject {
    static let storageKey = "dailyStarsData"

    @Published private(set) var stars: [DailyStarItem] = []
    @Published private(set) var selectedStar: DailyStarItem?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadFromStorage() {
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        restore(from: raw)
    }

    func restore(from raw: String) {
        let pairs = raw.split(separator: "|")
        let restored: [DailyStarItem] = pairs.compactMap { pair -> DailyStarItem? in
            let components = pair.split(separator: ",")
            guard components.count == 3,
                  let x = Double(components[0]),
                  let y = Double(components[1]),
                  let timestamp = TimeInterval(components[2]) else {
                return nil
            }

            return DailyStarItem(
                position: CGPoint(x: x, y: y),
                date: Date(timeIntervalSince1970: timestamp)
            )
        }

        stars = restored
        if let selectedStar, !stars.contains(where: { $0.id == selectedStar.id }) {
            self.selectedStar = nil
        }
    }

    func append(_ point: CGPoint, date: Date = Date()) {
        stars.append(DailyStarItem(position: point, date: date))
        persist()
    }

    func clearSelection() {
        selectedStar = nil
    }

    func select(_ item: DailyStarItem?) {
        selectedStar = item
    }

    private func persist() {
        let payload = stars
            .map { "\($0.position.x),\($0.position.y),\($0.date.timeIntervalSince1970)" }
            .joined(separator: "|")
        defaults.set(payload, forKey: Self.storageKey)
    }
}
