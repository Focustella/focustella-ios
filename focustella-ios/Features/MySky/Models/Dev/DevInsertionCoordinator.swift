import SwiftUI
import Combine
import os

@MainActor
final class DevInsertionCoordinator: ObservableObject {
    private static let logger = Logger(subsystem: "focustella-ios", category: "DevInsertion")

    struct PlacementProbeResult {
        let step: Int
        let constellationId: UUID?
        let placementKey: String
        let overlapDetected: Bool
        let representativePoint: CGPoint?
        let message: String
    }

    struct Context {
        var skyState: Binding<MySkySceneState>
        var edgeRevealTokens: Binding<[UUID: Int]>
        var selectedSession: Binding<FocusSession?>
        let sessionStore: SessionStore
        let repository: ConstellationRepository
        let localUserId: String
        let userSeed: Int64
    }

    @Published var seedText: String = "777"
    @Published var isCollapsed: Bool = true
    @Published var batchCount: Int = 1
    @Published var templateKind: ConstellationPlacementFixture.TemplateKind = .compactPentagon
    @Published private(set) var step: Int = 0
    @Published private(set) var lastResult: PlacementProbeResult?

    private var placedConstellationIds: Set<UUID> = []

    var summary: String {
        guard let result = lastResult else {
            return "현재 하늘 상태 위에 테스트 별자리를 한 개씩 올립니다."
        }

        let repText: String
        if let rep = result.representativePoint {
            repText = "x=\(String(format: "%.3f", rep.x)) y=\(String(format: "%.3f", rep.y))"
        } else {
            repText = "nil"
        }

        return "#\(result.step) \(result.message)\n\(result.placementKey)  overlap=\(result.overlapDetected ? "YES" : "NO")  rep=\(repText)"
    }

    func reset(context: Context) {
        guard !placedConstellationIds.isEmpty else {
            step = 0
            lastResult = nil
            return
        }

        context.skyState.wrappedValue.removeConstellations(ids: placedConstellationIds)
        context.sessionStore.removeCompletedSessions(constellationIds: placedConstellationIds)
        context.edgeRevealTokens.wrappedValue = context.edgeRevealTokens.wrappedValue.filter {
            !placedConstellationIds.contains($0.key)
        }

        if let selected = context.selectedSession.wrappedValue,
           placedConstellationIds.contains(selected.constellationId) {
            context.selectedSession.wrappedValue = nil
        }

        placedConstellationIds.removeAll()
        step = 0
        lastResult = nil
    }

    func placeNextBatch(context: Context) {
        for _ in 0..<batchCount {
            placeNextProbeConstellation(context: context)
        }
    }

    func insertUserConstellationAsCompleted(id: String, context: Context) async {
        Self.logger.notice("attempting dev constellation placement id=\(id, privacy: .public)")
        let inserted = await context.repository.fetchInsertedUserConstellation(
            id: id,
            userId: context.localUserId,
            occupied: context.skyState.wrappedValue.constellations,
            randomSeed: context.userSeed
        )

        guard let constellation = inserted else {
            Self.logger.error("dev constellation placement failed id=\(id, privacy: .public)")
            return
        }

        Self.logger.notice(
            "dev constellation placed id=\(id, privacy: .public) constellationId=\(constellation.id.uuidString, privacy: .public) stars=\(constellation.starCount)"
        )
        applyInsertedConstellationAsCompleted(constellation, selectSession: true, context: context)
    }

    func syncLocalInsertedConstellations(context: Context) async {
        let existingIds = Set(context.sessionStore.completedSessions.map(\.constellationId))
        let insertedConstellations = await context.repository.fetchCustomConstellations(
            userId: context.localUserId,
            occupied: context.skyState.wrappedValue.constellations,
            randomSeed: context.userSeed
        )

        Self.logger.notice(
            "sync local constellations fetched=\(insertedConstellations.count) existingSessions=\(existingIds.count)"
        )

        for constellation in insertedConstellations where !existingIds.contains(constellation.id) {
            Self.logger.notice(
                "rehydrating local constellation constellationId=\(constellation.id.uuidString, privacy: .public) name=\(constellation.name, privacy: .public)"
            )
            applyInsertedConstellationAsCompleted(constellation, selectSession: false, context: context)
        }
    }

    private func placeNextProbeConstellation(context: Context) {
        let placementKey = "probe-\(step)"
        let template = ConstellationPlacementFixture.template(templateKind, id: 100 + step)
        let constellation = context.repository.placeRemoteConstellation(
            template: template,
            placementKey: placementKey,
            occupied: context.skyState.wrappedValue.constellations,
            randomSeed: Int64(seedText) ?? 777
        )
        step += 1

        guard let constellation else {
            lastResult = PlacementProbeResult(
                step: step,
                constellationId: nil,
                placementKey: placementKey,
                overlapDetected: false,
                representativePoint: nil,
                message: "placement=nil"
            )
            return
        }

        let overlapDetected = MySkyPolygonGeometry.hasPolygonOverlap(
            candidate: constellation,
            occupied: context.skyState.wrappedValue.constellations
        )
        applyProbeConstellationToSky(constellation, context: context)
        placedConstellationIds.insert(constellation.id)
        lastResult = PlacementProbeResult(
            step: step,
            constellationId: constellation.id,
            placementKey: placementKey,
            overlapDetected: overlapDetected,
            representativePoint: constellation.representativePoint,
            message: "placed=\(constellation.name)"
        )
    }

    private func applyInsertedConstellationAsCompleted(
        _ constellation: Constellation,
        selectSession: Bool,
        context: Context
    ) {
        Self.logger.notice(
            "applying inserted constellation as completed constellationId=\(constellation.id.uuidString, privacy: .public) selectSession=\(selectSession)"
        )
        applySkippedCompletedConstellation(
            constellation,
            slotSeconds: 25 * 60,
            memo: SessionMemo(topicTags: ["dev", "inserted"], rating: 5, freeText: "Developer inserted constellation"),
            selectSession: selectSession,
            context: context
        )
    }

    private func applyProbeConstellationToSky(_ constellation: Constellation, context: Context) {
        applySkippedCompletedConstellation(
            constellation,
            slotSeconds: 15 * 60,
            memo: SessionMemo(topicTags: ["dev", "placement"], rating: 5, freeText: "Placement probe"),
            selectSession: false,
            context: context
        )
    }

    private func applySkippedCompletedConstellation(
        _ constellation: Constellation,
        slotSeconds: Int,
        memo: SessionMemo?,
        selectSession: Bool,
        context: Context
    ) {
        let session = skippedCompletedSession(constellation: constellation, slotSeconds: slotSeconds, memo: memo)
        applyCompletedSessionToSky(session, constellation: constellation, selectSession: selectSession, context: context)
    }

    private func applyCompletedSessionToSky(
        _ session: FocusSession,
        constellation: Constellation,
        selectSession: Bool,
        context: Context
    ) {
        context.skyState.wrappedValue.upsertConstellation(constellation)
        context.sessionStore.appendCompletedSession(session)
        Self.logger.notice(
            "completed session applied constellationId=\(constellation.id.uuidString, privacy: .public) sessionId=\(session.id.uuidString, privacy: .public) discovered=\(session.discoveredStarCount)"
        )
        context.skyState.wrappedValue.setVisibleDiscoveredCount(session.discoveredStarCount, for: constellation.id)
        context.skyState.wrappedValue.setEdgeRevealState(
            MySkyEdgeRevealState(
                committedDiscoveredCount: session.discoveredStarCount,
                pendingDiscoveredCount: nil,
                progress: 0
            ),
            for: constellation.id
        )

        if selectSession {
            context.selectedSession.wrappedValue = session
        }
    }

    private func skippedCompletedSession(
        constellation: Constellation,
        slotSeconds: Int,
        memo: SessionMemo?
    ) -> FocusSession {
        let endedAt = Date()
        return FocusSession(
            startedAt: endedAt.addingTimeInterval(TimeInterval(-slotSeconds)),
            endedAt: endedAt,
            slotSeconds: slotSeconds,
            constellationId: constellation.id,
            discoveredStarCount: constellation.starCount,
            status: .completed,
            memo: memo
        )
    }
}
