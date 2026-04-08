import SwiftUI

enum ConstellationMockPayloadCatalog {
    nonisolated static let basePayloads: [ServerConstellationPayload] = [
        cassiopeiaPayload(),
        delphinusPayload(),
        lyraPayload(),
        coronaBorealisPayload(),
        bigDipperPayload(),
        orionPayload(),
        leoPayload(),
        cygnusPayload(),
        scorpiusPayload(),
        pegasusPayload(),
        taurusPayload(),
        dracoPayload(),
        hydraPayload()
    ]

    nonisolated static func mixedPayload(step: Int, userSeed: Int64) -> ServerConstellationPayload? {
        guard !basePayloads.isEmpty else { return nil }
        let safeSeed = userSeed == 0 ? 0x9E37 : userSeed
        let base = UInt64(bitPattern: safeSeed)
        let stepBits = UInt64(truncatingIfNeeded: step)

        var mixed = base ^ (stepBits &* 0x9E37_79B9_7F4A_7C15)
        mixed ^= mixed >> 30
        mixed &*= 0xBF58_476D_1CE4_E5B9
        mixed ^= mixed >> 27
        mixed &*= 0x94D0_49BB_1331_11EB
        mixed ^= mixed >> 31

        let index = Int(mixed % UInt64(basePayloads.count))
        return basePayloads[index]
    }

    nonisolated private static func cassiopeiaPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-cassiopeia",
            name: "Cassiopeia",
            points: [
                CGPoint(x: -0.30, y: 0.08),
                CGPoint(x: -0.16, y: -0.08),
                CGPoint(x: -0.01, y: 0.09),
                CGPoint(x: 0.15, y: -0.06),
                CGPoint(x: 0.31, y: 0.10)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4)]
        )
    }

    nonisolated private static func delphinusPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-delphinus",
            name: "Delphinus",
            points: [
                CGPoint(x: -0.11, y: 0.02),
                CGPoint(x: 0.0, y: 0.12),
                CGPoint(x: 0.12, y: 0.03),
                CGPoint(x: 0.03, y: -0.11),
                CGPoint(x: -0.16, y: -0.05)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0)]
        )
    }

    nonisolated private static func lyraPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-lyra",
            name: "Lyra",
            points: [
                CGPoint(x: 0.0, y: 0.18),
                CGPoint(x: -0.15, y: 0.05),
                CGPoint(x: -0.1, y: -0.13),
                CGPoint(x: 0.08, y: -0.17),
                CGPoint(x: 0.17, y: -0.01),
                CGPoint(x: 0.03, y: 0.02)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 1)]
        )
    }

    nonisolated private static func coronaBorealisPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-corona-borealis",
            name: "Corona Borealis",
            points: [
                CGPoint(x: -0.28, y: -0.05),
                CGPoint(x: -0.18, y: 0.04),
                CGPoint(x: -0.07, y: 0.1),
                CGPoint(x: 0.06, y: 0.13),
                CGPoint(x: 0.18, y: 0.09),
                CGPoint(x: 0.27, y: 0.01),
                CGPoint(x: 0.33, y: -0.09)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6)]
        )
    }

    nonisolated private static func bigDipperPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-big-dipper",
            name: "Big Dipper",
            points: [
                CGPoint(x: -0.24, y: 0.12),
                CGPoint(x: -0.24, y: -0.03),
                CGPoint(x: -0.08, y: -0.07),
                CGPoint(x: 0.02, y: 0.05),
                CGPoint(x: 0.17, y: 0.10),
                CGPoint(x: 0.29, y: 0.12),
                CGPoint(x: 0.42, y: 0.08)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 0), (3, 4), (4, 5), (5, 6)]
        )
    }

    nonisolated private static func orionPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-orion",
            name: "Orion",
            points: [
                CGPoint(x: -0.22, y: 0.18),
                CGPoint(x: 0.16, y: 0.16),
                CGPoint(x: -0.12, y: 0.02),
                CGPoint(x: 0.0, y: 0.0),
                CGPoint(x: 0.12, y: -0.02),
                CGPoint(x: -0.18, y: -0.20),
                CGPoint(x: 0.2, y: -0.23),
                CGPoint(x: 0.28, y: -0.05)
            ],
            edges: [(0, 2), (2, 3), (3, 4), (4, 1), (2, 5), (4, 6), (1, 7)]
        )
    }

    nonisolated private static func leoPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-leo",
            name: "Leo",
            points: [
                CGPoint(x: -0.25, y: 0.03),
                CGPoint(x: -0.12, y: 0.14),
                CGPoint(x: 0.0, y: 0.03),
                CGPoint(x: 0.1, y: -0.08),
                CGPoint(x: 0.22, y: -0.16),
                CGPoint(x: 0.34, y: -0.05),
                CGPoint(x: 0.18, y: 0.02),
                CGPoint(x: 0.03, y: 0.16),
                CGPoint(x: -0.08, y: 0.22)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 2), (2, 7), (7, 8)]
        )
    }

    nonisolated private static func cygnusPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-cygnus",
            name: "Cygnus",
            points: [
                CGPoint(x: 0.0, y: 0.28),
                CGPoint(x: 0.0, y: 0.12),
                CGPoint(x: 0.0, y: -0.02),
                CGPoint(x: 0.0, y: -0.2),
                CGPoint(x: -0.22, y: 0.08),
                CGPoint(x: 0.22, y: 0.08),
                CGPoint(x: -0.14, y: -0.05),
                CGPoint(x: 0.16, y: -0.03),
                CGPoint(x: 0.0, y: -0.31)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 8), (4, 1), (1, 5), (6, 2), (2, 7)]
        )
    }

    nonisolated private static func scorpiusPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-scorpius",
            name: "Scorpius",
            points: [
                CGPoint(x: -0.28, y: 0.12),
                CGPoint(x: -0.16, y: 0.04),
                CGPoint(x: -0.04, y: -0.04),
                CGPoint(x: 0.08, y: -0.02),
                CGPoint(x: 0.18, y: 0.06),
                CGPoint(x: 0.24, y: -0.05),
                CGPoint(x: 0.18, y: -0.17),
                CGPoint(x: 0.26, y: -0.28),
                CGPoint(x: 0.16, y: -0.34),
                CGPoint(x: 0.31, y: -0.38)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8), (7, 9)]
        )
    }

    nonisolated private static func pegasusPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-pegasus",
            name: "Pegasus",
            points: [
                CGPoint(x: -0.18, y: 0.18),
                CGPoint(x: 0.12, y: 0.2),
                CGPoint(x: 0.18, y: -0.08),
                CGPoint(x: -0.13, y: -0.1),
                CGPoint(x: 0.28, y: 0.31),
                CGPoint(x: 0.39, y: 0.19),
                CGPoint(x: 0.47, y: 0.02),
                CGPoint(x: 0.34, y: -0.11),
                CGPoint(x: -0.28, y: 0.29),
                CGPoint(x: -0.38, y: 0.11),
                CGPoint(x: -0.31, y: -0.05),
                CGPoint(x: -0.18, y: -0.18)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 0), (1, 4), (4, 5), (5, 6), (6, 7), (0, 8), (8, 9), (9, 10), (10, 11)]
        )
    }

    nonisolated private static func taurusPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-taurus",
            name: "Taurus",
            points: [
                CGPoint(x: -0.06, y: 0.14),
                CGPoint(x: -0.21, y: 0.28),
                CGPoint(x: 0.1, y: 0.31),
                CGPoint(x: 0.0, y: 0.06),
                CGPoint(x: -0.18, y: -0.02),
                CGPoint(x: -0.32, y: -0.11),
                CGPoint(x: 0.16, y: -0.04),
                CGPoint(x: 0.31, y: -0.14),
                CGPoint(x: 0.42, y: -0.26),
                CGPoint(x: 0.24, y: -0.29),
                CGPoint(x: 0.06, y: -0.23),
                CGPoint(x: -0.07, y: -0.14)
            ],
            edges: [(0, 1), (0, 2), (0, 3), (3, 4), (4, 5), (3, 6), (6, 7), (7, 8), (8, 9), (9, 10), (10, 11), (11, 4)]
        )
    }

    nonisolated private static func dracoPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-draco",
            name: "Draco",
            points: [
                CGPoint(x: -0.32, y: 0.18),
                CGPoint(x: -0.2, y: 0.1),
                CGPoint(x: -0.09, y: 0.19),
                CGPoint(x: 0.05, y: 0.13),
                CGPoint(x: 0.17, y: 0.19),
                CGPoint(x: 0.28, y: 0.1),
                CGPoint(x: 0.18, y: 0.01),
                CGPoint(x: 0.05, y: -0.05),
                CGPoint(x: -0.07, y: -0.1),
                CGPoint(x: -0.15, y: -0.18),
                CGPoint(x: -0.03, y: -0.26),
                CGPoint(x: 0.12, y: -0.28),
                CGPoint(x: 0.23, y: -0.22),
                CGPoint(x: 0.34, y: -0.3),
                CGPoint(x: 0.43, y: -0.21)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8), (8, 9), (9, 10), (10, 11), (11, 12), (12, 13), (13, 14)]
        )
    }

    nonisolated private static func hydraPayload() -> ServerConstellationPayload {
        payload(
            id: "payload-hydra",
            name: "Hydra",
            points: [
                CGPoint(x: -0.42, y: 0.04),
                CGPoint(x: -0.33, y: 0.16),
                CGPoint(x: -0.24, y: 0.07),
                CGPoint(x: -0.16, y: -0.03),
                CGPoint(x: -0.06, y: 0.04),
                CGPoint(x: 0.03, y: -0.05),
                CGPoint(x: 0.14, y: 0.02),
                CGPoint(x: 0.23, y: -0.07),
                CGPoint(x: 0.33, y: -0.01),
                CGPoint(x: 0.42, y: -0.1),
                CGPoint(x: 0.34, y: -0.2),
                CGPoint(x: 0.23, y: -0.24),
                CGPoint(x: 0.13, y: -0.18),
                CGPoint(x: 0.02, y: -0.25),
                CGPoint(x: -0.09, y: -0.19),
                CGPoint(x: -0.19, y: -0.26),
                CGPoint(x: -0.29, y: -0.22),
                CGPoint(x: -0.38, y: -0.3),
                CGPoint(x: -0.26, y: -0.36),
                CGPoint(x: -0.12, y: -0.32)
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8), (8, 9), (9, 10), (10, 11), (11, 12), (12, 13), (13, 14), (14, 15), (15, 16), (16, 17), (17, 18), (18, 19)]
        )
    }

    nonisolated private static func payload(
        id: String,
        name: String,
        points: [CGPoint],
        edges: [(Int, Int)],
        visualStyle: ConstellationVisualStyle = .skyBlue
    ) -> ServerConstellationPayload {
        let representative = representativePoint(from: points)
        let stars = points.enumerated().map { index, point in
            ServerRelativeStar(
                id: "s\(index)",
                dx: point.x - representative.x,
                dy: point.y - representative.y
            )
        }

        let serverEdges = edges.map { ServerEdge(fromId: "s\($0.0)", toId: "s\($0.1)") }

        return ServerConstellationPayload(
            id: id,
            name: name,
            visualStyle: visualStyle,
            representativePoint: ServerPoint(x: representative.x, y: representative.y),
            stars: stars,
            edges: serverEdges,
            serverId: nil
        )
    }

    nonisolated private static func representativePoint(from points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return CGPoint(
            x: ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2,
            y: ((ys.min() ?? 0) + (ys.max() ?? 0)) / 2
        )
    }
}
