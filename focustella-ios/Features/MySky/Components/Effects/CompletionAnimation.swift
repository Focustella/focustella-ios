import SwiftUI

struct CompletionAnimation: View {
    let constellation: Constellation
    let reduceMotion: Bool
    let highPerformanceMode: Bool
    let edgeRevealOrder: [Int]
    let userSeed: Int
    let onFinished: () -> Void

    @State private var sparklingIndices: Set<Int> = []
    @State private var edgeProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ConstellationRenderer(
                constellation: constellation,
                coordinateMapper: MySkyCoordinateMapper(canvasSize: proxy.size),
                discoveredStarCount: constellation.starCount,
                showEdges: true,
                edgeProgress: edgeProgress,
                reduceMotion: reduceMotion,
                highPerformanceMode: highPerformanceMode,
                sparklingIndices: sparklingIndices,
                edgeRevealOrder: edgeRevealOrder,
                activeBirthEffect: nil,
                userSeed: userSeed
            )
            .task {
                await runSequence()
            }
        }
    }

    private func runSequence() async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.45)) {
                edgeProgress = 1
            }
            try? await Task.sleep(for: .milliseconds(500))
            Haptics.success()
            onFinished()
            return
        }

        for index in sparkleOrder().prefix(8) {
            sparklingIndices = [index]
            try? await Task.sleep(for: .milliseconds(90))
        }
        sparklingIndices = []

        withAnimation(.easeOut(duration: 0.8)) {
            edgeProgress = 1
        }

        try? await Task.sleep(for: .milliseconds(850))
        Haptics.success()
        onFinished()
    }

    private func sparkleOrder() -> [Int] {
        guard !constellation.stars.isEmpty else { return [] }

        var adjacency: [UUID: Set<UUID>] = [:]
        for edge in constellation.edges {
            adjacency[edge.from, default: []].insert(edge.to)
            adjacency[edge.to, default: []].insert(edge.from)
        }

        let idToIndex = Dictionary(uniqueKeysWithValues: constellation.stars.enumerated().map { ($0.element.id, $0.offset) })
        let start = constellation.stars[0].id
        var queue: [UUID] = [start]
        var visited: Set<UUID> = [start]
        var order: [Int] = []

        while !queue.isEmpty {
            let current = queue.removeFirst()
            if let index = idToIndex[current] {
                order.append(index)
            }
            for next in adjacency[current, default: []] where !visited.contains(next) {
                visited.insert(next)
                queue.append(next)
            }
        }

        if order.count < constellation.starCount {
            for index in constellation.stars.indices where !order.contains(index) {
                order.append(index)
            }
        }
        return order
    }
}
