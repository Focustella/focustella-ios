import SwiftUI

struct NightSkyBackgroundView: View {
    let style: NightSkyBackgroundStyle
    var extendsIntoSafeArea: Bool = true

    var body: some View {
        let background = backgroundContent.allowsHitTesting(false)

        if extendsIntoSafeArea {
            background.ignoresSafeArea()
        } else {
            background
        }
    }

    @ViewBuilder
    private var backgroundContent: some View {
        switch style {
        case .demo:
            DemoNightSkyBackgroundView()
        case .mySkyFocusStar:
            FocusStarSkyBackgroundView()
        case .mySkyLegacy:
            LegacyMySkyBackgroundView()
        case .mySkyAurora:
            AuroraMySkyBackgroundView()
        case .mySkyDeepSpace:
            DeepSpaceMySkyBackgroundView()
        }
    }
}

enum NightSkyBackgroundStyle {
    case demo
    case mySkyFocusStar
    case mySkyLegacy
    case mySkyAurora
    case mySkyDeepSpace
}

struct NightSkyStarField: View {
    var seed: UInt64? = nil
    let count: Int
    var salt: String = "night-sky-field"
    var profile: NightSkyStarProfile = .standard

    private var stars: [NightSkyStarSpec] {
        NightSkyStarFactory.makeStars(
            count: count,
            seed: seed,
            salt: salt,
            profile: profile
        )
    }

    var body: some View {
        GeometryReader { _ in
            // Draw stars in a single canvas pass to avoid one SwiftUI view per star.
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                for star in stars {
                    let center = CGPoint(x: star.x * size.width, y: star.y * size.height)
                    let coreDiameter = max(0.8, star.size)
                    let glowDiameter = coreDiameter + star.glowRadius * 2.2

                    let glowRect = CGRect(
                        x: center.x - glowDiameter / 2,
                        y: center.y - glowDiameter / 2,
                        width: glowDiameter,
                        height: glowDiameter
                    )
                    context.fill(
                        Path(ellipseIn: glowRect),
                        with: .color(Color.white.opacity(star.opacity * 0.28))
                    )

                    let coreRect = CGRect(
                        x: center.x - coreDiameter / 2,
                        y: center.y - coreDiameter / 2,
                        width: coreDiameter,
                        height: coreDiameter
                    )
                    context.fill(
                        Path(ellipseIn: coreRect),
                        with: .color(Color.white.opacity(star.opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct DemoNightSkyBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [FocusStarPalette.demoTop, FocusStarPalette.skyMid, FocusStarPalette.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(FocusStarPalette.goldGlow.opacity(0.16))
                .frame(width: 240, height: 240)
                .blur(radius: 50)
                .offset(x: -140, y: -300)

            Circle()
                .fill(FocusStarPalette.cyanGlow.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 130, y: 260)

            NightSkyStarField(count: 72, salt: "background-demo")
                .accessibilityHidden(true)
        }
    }
}
