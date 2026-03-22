import Foundation

struct StarBirthEffectState: Equatable {
    let constellationId: UUID
    let starId: UUID
    let connectionPairs: [StarBirthConnectionPair]
    let token: Int
}

struct StarBirthConnectionPair: Hashable {
    let fromStarId: UUID
    let toStarId: UUID
}
