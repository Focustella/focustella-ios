import SwiftUI
import Foundation
import os

struct DevConstellationStudioView: View {
    private static let logger = Logger(subsystem: "focustella-ios", category: "DevConstellation")

    @AppStorage("userId") private var userId: String = ""
    @State private var name: String = ""
    @State private var relativePoints: [CGPoint] = []
    @State private var closeLoop: Bool = false
    @State private var isSaving: Bool = false
    @State private var message: String?

    private let repository = ConstellationRepository()
    private let fallbackLocalUserId = "local-user"

    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section("별자리 정보") {
                    TextField("이름", text: $name)
                    Toggle("루프 닫기(마지막-처음 연결)", isOn: $closeLoop)
                    Text("별 개수: \(relativePoints.count)")
                        .foregroundStyle(.secondary)
                }

                Section("캔버스") {
                    GeometryReader { proxy in
                        let size = proxy.size
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.05))

                            Path { path in
                                let edges = buildEdges(count: relativePoints.count, closeLoop: closeLoop)
                                for edge in edges {
                                    let a = toCanvas(relativePoints[edge.0], size: size)
                                    let b = toCanvas(relativePoints[edge.1], size: size)
                                    path.move(to: a)
                                    path.addLine(to: b)
                                }
                            }
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)

                            ForEach(relativePoints.indices, id: \.self) { index in
                                let point = toCanvas(relativePoints[index], size: size)
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                    .position(point)
                            }

                            VStack {
                                Spacer()
                                Text("탭해서 별 추가")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.bottom, 8)
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    let relative = toRelative(value.location, size: size)
                                    relativePoints.append(relative)
                                }
                        )
                    }
                    .frame(height: 320)
                }
            }

            HStack(spacing: 10) {
                Button("마지막 삭제") {
                    _ = relativePoints.popLast()
                }
                .buttonStyle(.bordered)
                .disabled(relativePoints.isEmpty)

                Button("전체 삭제", role: .destructive) {
                    relativePoints.removeAll()
                }
                .buttonStyle(.bordered)
                .disabled(relativePoints.isEmpty)

                Button(isSaving ? "삽입 중..." : "별자리 삽입") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || relativePoints.count < 3)
            }
            .padding(.horizontal, 16)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle("별자리 생성/삽입")
        .background(Color.black.ignoresSafeArea())
    }

    private func save() {
        let constellationName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard constellationName.isEmpty == false, relativePoints.count >= 3 else { return }

        isSaving = true
        message = nil

        let edges = buildEdges(count: relativePoints.count, closeLoop: closeLoop)
        Task { @MainActor in
            let targetUserId = userId.isEmpty ? fallbackLocalUserId : userId
            Self.logger.notice("dev insert request name=\(constellationName, privacy: .public) userId=\(targetUserId, privacy: .public) stars=\(relativePoints.count) edges=\(edges.count)")
            let insertedId = await repository.insertUserConstellation(
                userId: targetUserId,
                name: constellationName,
                relativeStars: relativePoints,
                edges: edges,
                visualStyle: .debugRed
            )
            isSaving = false
            if let insertedId {
                Self.logger.notice("dev insert stored id=\(insertedId, privacy: .public)")
                message = "삽입 완료: MySky에 바로 반영됩니다."
            } else {
                Self.logger.error("dev insert failed to store constellation")
                message = "삽입 실패: 로그를 확인하세요."
            }
            NotificationCenter.default.post(name: .didInsertUserConstellation, object: insertedId)
        }
    }

    private func buildEdges(count: Int, closeLoop: Bool) -> [(Int, Int)] {
        guard count >= 2 else { return [] }
        var edges: [(Int, Int)] = []
        for i in 0..<(count - 1) {
            edges.append((i, i + 1))
        }
        if closeLoop && count > 2 {
            edges.append((count - 1, 0))
        }
        return edges
    }

    private func toCanvas(_ point: CGPoint, size: CGSize) -> CGPoint {
        let side = min(size.width, size.height)
        return CGPoint(
            x: size.width * 0.5 + point.x * side,
            y: size.height * 0.5 + point.y * side
        )
    }

    private func toRelative(_ point: CGPoint, size: CGSize) -> CGPoint {
        let side = max(1, min(size.width, size.height))
        let x = (point.x - size.width * 0.5) / side
        let y = (point.y - size.height * 0.5) / side
        return CGPoint(x: min(max(x, -0.48), 0.48), y: min(max(y, -0.48), 0.48))
    }
}

extension Notification.Name {
    static let didInsertUserConstellation = Notification.Name("didInsertUserConstellation")
}

#Preview {
    NavigationStack {
        DevConstellationStudioView()
    }
}
