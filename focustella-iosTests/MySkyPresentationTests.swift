import XCTest
import CoreGraphics
@testable import focustella_ios

final class MySkyPresentationTests: XCTestCase {
    func testCenteredCameraPlacesTargetStarAtScreenCenter() {
        let mapper = MySkyCoordinateMapper(canvasSize: CGSize(width: 390, height: 844))
        let controller = MySkyCameraController(mapper: mapper)
        let star = Star(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, x: 1.034, y: 0.169)

        let camera = controller.centeredCamera(forStar: star, zoom: 2.0)
        let screenPoint = mapper.screenPoint(fromSky: CGPoint(x: star.x, y: star.y), camera: camera)

        XCTAssertEqual(screenPoint.x, mapper.screenCenter.x, accuracy: 0.001)
        XCTAssertEqual(screenPoint.y, mapper.screenCenter.y, accuracy: 0.001)
        XCTAssertEqual(camera.centerSky.x, star.x, accuracy: 0.000001)
        XCTAssertEqual(camera.centerSky.y, star.y, accuracy: 0.000001)
    }

    func testOverviewCameraFitsEntireConstellationWithinPaddedViewport() {
        let mapper = MySkyCoordinateMapper(canvasSize: CGSize(width: 390, height: 844))
        let controller = MySkyCameraController(mapper: mapper)
        let constellation = sampleConstellation(
            stars: [
                CGPoint(x: -0.35, y: 0.10),
                CGPoint(x: 1.45, y: 0.12),
                CGPoint(x: -0.10, y: 1.22),
                CGPoint(x: 1.20, y: 1.18)
            ]
        )

        let camera = controller.overviewCamera(for: constellation, padding: 72)
        let insetBounds = CGRect(x: 72, y: 72, width: mapper.canvasSize.width - 144, height: mapper.canvasSize.height - 144)
            .insetBy(dx: -0.5, dy: -0.5)

        for star in constellation.stars {
            let screenPoint = mapper.screenPoint(fromSky: CGPoint(x: star.x, y: star.y), camera: camera)
            XCTAssertTrue(insetBounds.contains(screenPoint), "Expected \(screenPoint) to fit inside \(insetBounds)")
        }
    }

    func testDiscoveryOrderStartsFromVisualCenterInsteadOfRawArrayOrder() {
        let constellation = sampleConstellation(
            stars: [
                CGPoint(x: 0.92, y: 0.16),
                CGPoint(x: 0.52, y: 0.48),
                CGPoint(x: 0.18, y: 0.82)
            ],
            edges: [(1, 0), (1, 2)]
        )

        let presentation = MySkyFocusSessionPresentation(
            constellation: constellation,
            actualDiscoveredCount: 0,
            renderedDiscoveredCount: 0,
            edgeRevealState: MySkyEdgeRevealState(),
            activeBirthEffect: nil
        )

        XCTAssertEqual(presentation.discoveryOrder.first, 1)
        XCTAssertEqual(Set(presentation.discoveryOrder), Set([0, 1, 2]))
    }

    func testPresentationStateBeginsBirthOnlyWhenActualDiscoveryOutrunsRenderedCount() {
        var state = FocusSessionPresentationState(
            constellationId: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA"),
            discoveryOrder: [2, 0, 1],
            actualDiscoveredCount: 1,
            renderedDiscoveredCount: 0,
            currentTargetOrderIndex: 0,
            activeBirthStarId: nil,
            phase: .waitingToBirth(orderIndex: 0),
            clock: .live
        )

        XCTAssertTrue(state.canBeginBirth)

        state.phase = .movingToTarget(orderIndex: 0)
        XCTAssertFalse(state.canBeginBirth)

        state.phase = .waitingToBirth(orderIndex: 1)
        state.renderedDiscoveredCount = 1
        state.actualDiscoveredCount = 1
        XCTAssertFalse(state.canBeginBirth)
    }

    func testStateMergerKeepsLocalConstellationPlacementForMatchingServerSession() {
        let localConstellation = sampleConstellation(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000CAFE")!,
            stars: [
                CGPoint(x: 1.10, y: 0.25),
                CGPoint(x: 1.28, y: 0.44)
            ]
        )
        let remoteConstellation = sampleConstellation(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000D00D")!,
            stars: [
                CGPoint(x: 0.18, y: 0.77),
                CGPoint(x: 0.32, y: 0.88)
            ]
        )
        let localSession = FocusSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
            serverSessionId: "session-1",
            serverConstellationId: 91,
            startedAt: .distantPast,
            endedAt: .distantPast.addingTimeInterval(10),
            slotSeconds: 1500,
            constellationId: localConstellation.id,
            discoveredStarCount: localConstellation.starCount,
            status: .completed
        )
        let remoteSession = FocusSession(
            id: localSession.id,
            serverSessionId: "session-1",
            serverConstellationId: 91,
            startedAt: localSession.startedAt,
            endedAt: localSession.endedAt,
            slotSeconds: localSession.slotSeconds,
            constellationId: remoteConstellation.id,
            discoveredStarCount: remoteConstellation.starCount,
            status: .completed
        )

        let snapshot = MySkySnapshot(
            seed: 7,
            dailyStars: [],
            remoteFocusLayoutItems: [],
            completedSessions: [remoteSession],
            constellations: [remoteConstellation]
        )
        let merger = MySkyStateMerger(
            placedConstellations: [localConstellation],
            completedSessions: [localSession]
        )

        let merged = merger.mergeRemoteSkyWithLocalState(snapshot)

        XCTAssertEqual(merged.completedSessions.first?.constellationId, localConstellation.id)
        XCTAssertEqual(merged.constellations.first?.id, localConstellation.id)
        XCTAssertEqual(merged.constellations.first?.stars.first?.x, localConstellation.stars.first?.x)
        XCTAssertEqual(merged.constellations.first?.stars.first?.y, localConstellation.stars.first?.y)
    }

    private func sampleConstellation(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-00000000BEEF")!,
        stars points: [CGPoint],
        edges indexPairs: [(Int, Int)]? = nil
    ) -> Constellation {
        let stars = points.enumerated().map { index, point in
            Star(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
                x: point.x,
                y: point.y
            )
        }
        let edges: [Edge]
        if let indexPairs {
            edges = indexPairs.map { pair in
                Edge(from: stars[pair.0].id, to: stars[pair.1].id)
            }
        } else {
            edges = zip(stars, stars.dropFirst()).map { Edge(from: $0.id, to: $1.id) }
        }

        return Constellation(
            id: id,
            name: "Test",
            stars: stars,
            edges: edges
        )
    }
}
