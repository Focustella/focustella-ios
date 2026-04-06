import SwiftUI

enum ConstellationPlacementFixture {
    enum TemplateKind: String, CaseIterable, Identifiable {
        case mixed
        case compactPentagon
        case tallKite
        case wideWave
        case zigzagHex

        var id: String { rawValue }

        var title: String {
            switch self {
            case .mixed: return "Mixed"
            case .compactPentagon: return "Compact-5"
            case .tallKite: return "Tall-Kite"
            case .wideWave: return "Wide-Wave"
            case .zigzagHex: return "Zigzag-6"
            }
        }
    }

    static func template(_ kind: TemplateKind, id: Int) -> ConstellationDTO {
        switch kind {
        case .mixed:
            return mixedTemplate(id: id)
        case .compactPentagon:
            return compactTemplate(id: id)
        case .tallKite:
            return tallKiteTemplate(id: id)
        case .wideWave:
            return wideWaveTemplate(id: id)
        case .zigzagHex:
            return zigzagHexTemplate(id: id)
        }
    }

    static func mixedTemplate(id: Int) -> ConstellationDTO {
        let variants: [TemplateKind] = [.compactPentagon, .tallKite, .wideWave, .zigzagHex]
        let index = abs(id) % variants.count
        return template(variants[index], id: id)
    }

    static func compactTemplate(id: Int) -> ConstellationDTO {
        ConstellationDTO(
            id: id,
            name: "Test-\(id)",
            createdBy: nil,
            starCount: 5,
            defaultScale: 1,
            minScale: 1,
            maxScale: 1,
            createdAt: "2026-04-02T00:00:00Z",
            updatedAt: "2026-04-02T00:00:00Z",
            stars: [
                .init(id: 1, vectorX: -0.09, vectorY: -0.03),
                .init(id: 2, vectorX: 0.0, vectorY: 0.1),
                .init(id: 3, vectorX: 0.11, vectorY: 0.02),
                .init(id: 4, vectorX: 0.04, vectorY: -0.11),
                .init(id: 5, vectorX: -0.1, vectorY: -0.08)
            ],
            edges: [
                .init(id: 1, fromStarId: 1, toStarId: 2),
                .init(id: 2, fromStarId: 2, toStarId: 3),
                .init(id: 3, fromStarId: 3, toStarId: 4),
                .init(id: 4, fromStarId: 4, toStarId: 5),
                .init(id: 5, fromStarId: 5, toStarId: 1)
            ]
        )
    }

    static func tallKiteTemplate(id: Int) -> ConstellationDTO {
        ConstellationDTO(
            id: id,
            name: "Tall-\(id)",
            createdBy: nil,
            starCount: 5,
            defaultScale: 1,
            minScale: 1,
            maxScale: 1,
            createdAt: "2026-04-02T00:00:00Z",
            updatedAt: "2026-04-02T00:00:00Z",
            stars: [
                .init(id: 1, vectorX: 0.0, vectorY: -0.14),
                .init(id: 2, vectorX: 0.09, vectorY: -0.02),
                .init(id: 3, vectorX: 0.03, vectorY: 0.13),
                .init(id: 4, vectorX: -0.08, vectorY: 0.02),
                .init(id: 5, vectorX: -0.02, vectorY: -0.04)
            ],
            edges: [
                .init(id: 1, fromStarId: 1, toStarId: 2),
                .init(id: 2, fromStarId: 2, toStarId: 3),
                .init(id: 3, fromStarId: 3, toStarId: 4),
                .init(id: 4, fromStarId: 4, toStarId: 1),
                .init(id: 5, fromStarId: 1, toStarId: 5),
                .init(id: 6, fromStarId: 5, toStarId: 3)
            ]
        )
    }

    static func wideWaveTemplate(id: Int) -> ConstellationDTO {
        ConstellationDTO(
            id: id,
            name: "Wave-\(id)",
            createdBy: nil,
            starCount: 6,
            defaultScale: 1,
            minScale: 1,
            maxScale: 1,
            createdAt: "2026-04-02T00:00:00Z",
            updatedAt: "2026-04-02T00:00:00Z",
            stars: [
                .init(id: 1, vectorX: -0.14, vectorY: 0.02),
                .init(id: 2, vectorX: -0.08, vectorY: -0.07),
                .init(id: 3, vectorX: -0.01, vectorY: 0.05),
                .init(id: 4, vectorX: 0.06, vectorY: -0.08),
                .init(id: 5, vectorX: 0.13, vectorY: 0.01),
                .init(id: 6, vectorX: 0.04, vectorY: 0.1)
            ],
            edges: [
                .init(id: 1, fromStarId: 1, toStarId: 2),
                .init(id: 2, fromStarId: 2, toStarId: 3),
                .init(id: 3, fromStarId: 3, toStarId: 4),
                .init(id: 4, fromStarId: 4, toStarId: 5),
                .init(id: 5, fromStarId: 3, toStarId: 6)
            ]
        )
    }

    static func zigzagHexTemplate(id: Int) -> ConstellationDTO {
        ConstellationDTO(
            id: id,
            name: "Zigzag-\(id)",
            createdBy: nil,
            starCount: 6,
            defaultScale: 1,
            minScale: 1,
            maxScale: 1,
            createdAt: "2026-04-02T00:00:00Z",
            updatedAt: "2026-04-02T00:00:00Z",
            stars: [
                .init(id: 1, vectorX: -0.12, vectorY: -0.09),
                .init(id: 2, vectorX: -0.05, vectorY: 0.02),
                .init(id: 3, vectorX: 0.01, vectorY: -0.08),
                .init(id: 4, vectorX: 0.08, vectorY: 0.03),
                .init(id: 5, vectorX: 0.14, vectorY: -0.05),
                .init(id: 6, vectorX: 0.03, vectorY: 0.11)
            ],
            edges: [
                .init(id: 1, fromStarId: 1, toStarId: 2),
                .init(id: 2, fromStarId: 2, toStarId: 3),
                .init(id: 3, fromStarId: 3, toStarId: 4),
                .init(id: 4, fromStarId: 4, toStarId: 5),
                .init(id: 5, fromStarId: 2, toStarId: 6),
                .init(id: 6, fromStarId: 6, toStarId: 4)
            ]
        )
    }

    static func blockingConstellation() -> Constellation {
        let stars = [
            Star(x: 0.08, y: 0.08),
            Star(x: 0.92, y: 0.08),
            Star(x: 0.92, y: 0.92),
            Star(x: 0.08, y: 0.92)
        ]

        return Constellation(
            name: "Blocking",
            representativePoint: CGPoint(x: 0.5, y: 0.5),
            stars: stars,
            edges: [
                Edge(from: stars[0].id, to: stars[1].id),
                Edge(from: stars[1].id, to: stars[2].id),
                Edge(from: stars[2].id, to: stars[3].id),
                Edge(from: stars[3].id, to: stars[0].id)
            ]
        )
    }
}
