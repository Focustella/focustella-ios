import SwiftUI

actor MockConstellationService {
    private let basePayloads: [ServerConstellationPayload]
    private var customPayloadsByUser: [String: [ServerConstellationPayload]] = [:]
    private var lastSessionPayloadIdByUser: [String: String] = [:]

    init() {
        self.basePayloads = ConstellationMockPayloadCatalog.basePayloads
    }

    func fetchConstellation(durationSeconds: Int, userId: String) async -> ServerConstellationPayload? {
        let candidates = await fetchConstellationCandidates(durationSeconds: durationSeconds, userId: userId)
        return candidates.first
    }

    func fetchConstellationCandidates(durationSeconds: Int, userId: String) async -> [ServerConstellationPayload] {
        try? await Task.sleep(for: .milliseconds(240))
        let payloads = allPayloads(for: userId)

        let range: ClosedRange<Int>
        switch durationSeconds {
        case ..<3600: range = 5...7
        case 3600..<7200: range = 8...10
        case 7200..<10800: range = 11...20
        default: range = 21...40
        }

        let preferred = payloads.filter { range.contains($0.stars.count) }
        let pool = preferred.isEmpty ? payloads : preferred
        guard !pool.isEmpty else { return [] }

        var shuffled = pool.shuffled()
        if let lastId = lastSessionPayloadIdByUser[userId],
           shuffled.count > 1,
           let lastIndex = shuffled.firstIndex(where: { $0.id == lastId }) {
            let lastPayload = shuffled.remove(at: lastIndex)
            shuffled.append(lastPayload)
        }
        lastSessionPayloadIdByUser[userId] = shuffled.first?.id
        return shuffled
    }

    func fetchConstellationsForUser(userId: String) async -> [ServerConstellationPayload] {
        try? await Task.sleep(for: .milliseconds(220))
        let custom = customPayloadsByUser[userId] ?? []
        var shuffledBase = basePayloads

        var state = UInt64(abs(userId.hashValue))
        func next(_ state: inout UInt64) -> UInt64 {
            state = 6364136223846793005 &* state &+ 1442695040888963407
            return state
        }

        for i in shuffledBase.indices.reversed() where i > 0 {
            let j = Int(next(&state) % UInt64(i + 1))
            if i != j {
                shuffledBase.swapAt(i, j)
            }
        }

        // Always prioritize user-created constellations in MySky preview.
        let baseTake = max(0, 3 - custom.count)
        return custom + Array(shuffledBase.prefix(baseTake))
    }

    func fetchCustomConstellationsForUser(userId: String) async -> [ServerConstellationPayload] {
        customPayloadsByUser[userId] ?? []
    }

    func fetchBasePreviewConstellations(limit: Int) async -> [ServerConstellationPayload] {
        try? await Task.sleep(for: .milliseconds(180))
        return Array(basePayloads.prefix(max(0, limit)))
    }

    func fetchCustomConstellation(id: String, userId: String) async -> ServerConstellationPayload? {
        customPayloadsByUser[userId]?.first(where: { $0.id == id })
    }

    func insertConstellation(_ payload: ServerConstellationPayload, for userId: String) {
        var list = customPayloadsByUser[userId] ?? []
        list.insert(payload, at: 0)
        customPayloadsByUser[userId] = list
    }

    private func allPayloads(for userId: String) -> [ServerConstellationPayload] {
        let custom = customPayloadsByUser[userId] ?? []
        return custom + basePayloads
    }
}
