import Foundation

struct MySkyStateMerger {
    let placedConstellations: [Constellation]
    let completedSessions: [FocusSession]

    func mergeRemoteSkyWithLocalState(_ remoteSky: MySkySnapshot) -> MySkySnapshot {
        let localByServerSessionId = localConstellationsByServerSessionId()
        let reconciledRemote = reconcileRemoteWorld(
            sessions: remoteSky.completedSessions,
            constellations: remoteSky.constellations,
            localByServerSessionId: localByServerSessionId
        )
        let remoteServerSessionIds = Set(remoteSky.completedSessions.compactMap(\.serverSessionId))
        let localSessionsToPreserve = completedSessions.filter { session in
            guard placedConstellations.contains(where: { $0.id == session.constellationId }) else {
                return false
            }
            guard let serverSessionId = session.serverSessionId else {
                return true
            }

            return !remoteServerSessionIds.contains(serverSessionId)
        }

        let localConstellationsToPreserve = localSessionsToPreserve.compactMap { session in
            placedConstellations.first(where: { $0.id == session.constellationId })
        }

        return MySkySnapshot(
            seed: remoteSky.seed,
            dailyStars: remoteSky.dailyStars,
            remoteFocusLayoutItems: remoteSky.remoteFocusLayoutItems,
            completedSessions: mergedFocusSessions(remote: reconciledRemote.sessions, local: localSessionsToPreserve),
            constellations: mergedConstellations(
                remote: reconciledRemote.constellations,
                appendedLocal: localConstellationsToPreserve
            )
        )
    }

    func mergeLayout(
        _ layout: [FocusSkyLayoutResult]
    ) -> (constellations: [Constellation], completedSessions: [FocusSession]) {
        let rawRemoteCompletedSessions = layout
            .filter { $0.item.status == .completed }
            .map(\.session)
        let remoteConstellations = layout.map(\.constellation)
        let localByServerSessionId = localConstellationsByServerSessionId()
        let reconciledRemote = reconcileRemoteWorld(
            sessions: rawRemoteCompletedSessions,
            constellations: remoteConstellations,
            localByServerSessionId: localByServerSessionId
        )
        let remoteSessionIds = Set(layout.map { $0.item.sessionId })

        let localSessions = completedSessions.filter { session in
            guard placedConstellations.contains(where: { $0.id == session.constellationId }) else {
                return false
            }

            guard let serverSessionId = session.serverSessionId else {
                return true
            }

            return !remoteSessionIds.contains(serverSessionId)
        }
        let localConstellations = localSessions.compactMap { session in
            placedConstellations.first(where: { $0.id == session.constellationId })
        }

        return (
            constellations: mergedConstellations(remote: reconciledRemote.constellations, appendedLocal: localConstellations),
            completedSessions: mergedFocusSessions(remote: reconciledRemote.sessions, local: localSessions)
        )
    }

    private func localConstellationsByServerSessionId() -> [String: Constellation] {
        Dictionary(
            uniqueKeysWithValues: completedSessions.compactMap { session in
                guard let serverSessionId = session.serverSessionId,
                      let constellation = placedConstellations.first(where: { $0.id == session.constellationId }) else {
                    return nil
                }
                return (serverSessionId, constellation)
            }
        )
    }

    private func reconcileRemoteWorld(
        sessions: [FocusSession],
        constellations: [Constellation],
        localByServerSessionId: [String: Constellation]
    ) -> (sessions: [FocusSession], constellations: [Constellation]) {
        let remoteConstellationsById = Dictionary(uniqueKeysWithValues: constellations.map { ($0.id, $0) })
        var reconciledSessions: [FocusSession] = []
        var reconciledConstellations: [Constellation] = []
        var seenIds: Set<UUID> = []

        for session in sessions {
            if let serverSessionId = session.serverSessionId,
               let localConstellation = localByServerSessionId[serverSessionId] {
                reconciledSessions.append(copy(session, constellationId: localConstellation.id))
                if seenIds.insert(localConstellation.id).inserted {
                    reconciledConstellations.append(localConstellation)
                }
                continue
            }

            reconciledSessions.append(session)
            if let constellation = remoteConstellationsById[session.constellationId],
               seenIds.insert(constellation.id).inserted {
                reconciledConstellations.append(constellation)
            }
        }

        for constellation in constellations where seenIds.insert(constellation.id).inserted {
            reconciledConstellations.append(constellation)
        }

        return (reconciledSessions, reconciledConstellations)
    }

    private func mergedFocusSessions(remote: [FocusSession], local: [FocusSession]) -> [FocusSession] {
        var result: [FocusSession] = remote
        let existingKeys = Set(remote.map(sessionIdentityKey))

        for session in local where !existingKeys.contains(sessionIdentityKey(session)) {
            result.append(session)
        }

        return result.sorted { lhs, rhs in
            (lhs.endedAt ?? lhs.startedAt) > (rhs.endedAt ?? rhs.startedAt)
        }
    }

    private func mergedConstellations(remote: [Constellation], appendedLocal: [Constellation]) -> [Constellation] {
        let preferredById = Dictionary(uniqueKeysWithValues: placedConstellations.map { ($0.id, $0) })
        var result: [Constellation] = []
        var seenIds: Set<UUID> = []

        for constellation in remote {
            let merged = preferredById[constellation.id] ?? constellation
            guard seenIds.insert(merged.id).inserted else { continue }
            result.append(merged)
        }

        for constellation in appendedLocal where seenIds.insert(constellation.id).inserted {
            result.append(constellation)
        }

        return result
    }

    private func sessionIdentityKey(_ session: FocusSession) -> String {
        if let serverSessionId = session.serverSessionId {
            return "server:\(serverSessionId)"
        }
        return "local:\(session.id.uuidString)"
    }

    private func copy(_ session: FocusSession, constellationId: UUID) -> FocusSession {
        FocusSession(
            id: session.id,
            serverSessionId: session.serverSessionId,
            serverConstellationId: session.serverConstellationId,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            slotSeconds: session.slotSeconds,
            constellationId: constellationId,
            discoveredStarCount: session.discoveredStarCount,
            status: session.status,
            memo: session.memo
        )
    }
}
