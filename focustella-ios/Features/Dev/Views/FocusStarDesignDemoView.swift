import SwiftUI

struct FocusStarDesignDemoView: View {
    @State private var selectedTab: DemoTab = .mySky
    @State private var isTwinkling = false

    var body: some View {
        ZStack {
            NightSkyBackgroundView(style: .demo)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    heroSection
                    constellationCard
                    controlButtons
                    tabPreview
                    paletteStrip
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Focus Star Demo")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear {
            isTwinkling = true
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Night Sky Showcase")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(FocusStarPalette.mistText)

            Text("Focus session UI concept")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("다운로드한 샘플의 색감, 별 배경, 버튼 톤을 현재 프로젝트 안에서 한 화면으로 확인할 수 있게 묶은 데모입니다.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var constellationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MySky")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("대표 별자리 표현")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                Spacer()

                Text("8 / 10 stars")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.98, green: 0.85, blue: 0.37))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }

            DemoConstellationCanvas(isTwinkling: isTwinkling)
                .frame(height: 260)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.04), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var controlButtons: some View {
        VStack(spacing: 12) {
            DemoActionButton(
                title: "모양 변경: 눈꽃 8각",
                icon: "hammer.fill",
                background: Color(red: 0.98, green: 0.85, blue: 0.37),
                foreground: Color.black
            )

            DemoActionButton(
                title: "오늘 하루 계획하기",
                icon: nil,
                background: Color(red: 0.25, green: 0.28, blue: 0.35),
                foreground: .white
            )

            DemoActionButton(
                title: "집중 세션 시작",
                icon: nil,
                background: .white,
                foreground: .black
            )
        }
    }

    private var tabPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tab Preview")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                ForEach(DemoTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(selectedTab == tab ? Color.black : Color.white.opacity(0.72))
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selectedTab == tab ? Color(red: 0.00, green: 0.83, blue: 1.00) : Color.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(22)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var paletteStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Palette")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                DemoPaletteSwatch(name: "Sky", color: Color(red: 0.04, green: 0.09, blue: 0.16))
                DemoPaletteSwatch(name: "Gold", color: FocusStarPalette.goldGlow)
                DemoPaletteSwatch(name: "Primary", color: FocusStarPalette.goldGlow)
                DemoPaletteSwatch(name: "Cyan", color: FocusStarPalette.cyanGlow)
            }
        }
        .padding(22)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private enum DemoTab: CaseIterable {
    case mySky
    case constellation
    case friends
    case settings

    var title: String {
        switch self {
        case .mySky: return "MySky"
        case .constellation: return "Focus"
        case .friends: return "Friends"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .mySky: return "sparkles"
        case .constellation: return "star.leadinghalf.filled"
        case .friends: return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}


private struct DemoConstellationCanvas: View {
    let isTwinkling: Bool

    private let points: [CGPoint] = [
        CGPoint(x: 0.14, y: 0.64),
        CGPoint(x: 0.24, y: 0.46),
        CGPoint(x: 0.33, y: 0.56),
        CGPoint(x: 0.46, y: 0.34),
        CGPoint(x: 0.58, y: 0.24),
        CGPoint(x: 0.69, y: 0.38),
        CGPoint(x: 0.82, y: 0.21),
        CGPoint(x: 0.79, y: 0.66),
        CGPoint(x: 0.60, y: 0.74),
        CGPoint(x: 0.45, y: 0.67)
    ]

    private let connections: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 4), (4, 5),
        (5, 6), (5, 7), (7, 8), (8, 9), (9, 3)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Canvas { context, size in
                    for (from, to) in connections {
                        var path = Path()
                        path.move(to: scaled(points[from], in: size))
                        path.addLine(to: scaled(points[to], in: size))
                        context.stroke(
                            path,
                            with: .color(.white.opacity(0.26)),
                            lineWidth: 1.2
                        )
                    }
                }

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    DemoGlowingStar(
                        size: index == 4 || index == 6 ? 24 : (index % 3 == 0 ? 18 : 12),
                        isTwinkling: isTwinkling
                    )
                    .position(scaled(point, in: proxy.size))
                }
            }
        }
    }

    private func scaled(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}

private struct DemoGlowingStar: View {
    let size: CGFloat
    let isTwinkling: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.22))
                .frame(width: size * 2.4, height: size * 2.4)
                .blur(radius: size * 0.24)

            Image(systemName: "sparkle")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.97, blue: 0.86),
                            Color(red: 1.0, green: 0.84, blue: 0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.75), radius: size * 0.4)
                .scaleEffect(pulse ? 1.08 : 0.96)
        }
        .animation(
            isTwinkling ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : .default,
            value: pulse
        )
        .onAppear {
            pulse = true
        }
    }
}

private struct DemoActionButton: View {
    let title: String
    let icon: String?
    let background: Color
    let foreground: Color

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
            }

            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .foregroundStyle(foreground)
        .background(background, in: Capsule())
    }
}

private struct DemoPaletteSwatch: View {
    let name: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color)
                .frame(height: 54)

            Text(name)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        FocusStarDesignDemoView()
    }
}
