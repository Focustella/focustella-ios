import SwiftUI

struct MySkyBackgroundLayer: View {
    let canvasSize: CGSize
    let safeAreaInsets: EdgeInsets
    let scale: CGFloat
    let offset: CGSize
    let variant: MySkyBackgroundVariant

    private let baseExpansion: CGFloat = 2.9
    private let panResponse: CGFloat = 0.55
    private let zoomResponse: CGFloat = 0.72

    var body: some View {
        let viewportSize = CGSize(
            width: canvasSize.width + safeAreaInsets.leading + safeAreaInsets.trailing,
            height: canvasSize.height + safeAreaInsets.top + safeAreaInsets.bottom
        )
        let expandedSize = CGSize(
            width: max(viewportSize.width * baseExpansion, viewportSize.width + 920),
            height: max(viewportSize.height * baseExpansion, viewportSize.height + 1200)
        )
        let appliedScale = 1 + ((scale - 1) * zoomResponse)
        let scaledSize = CGSize(
            width: expandedSize.width * appliedScale,
            height: expandedSize.height * appliedScale
        )
        let maxTravel = CGSize(
            width: max(0, (scaledSize.width - viewportSize.width) / 2),
            height: max(0, (scaledSize.height - viewportSize.height) / 2)
        )
        let rawOffset = CGSize(
            width: offset.width * panResponse,
            height: offset.height * panResponse
        )
        let clampedOffset = CGSize(
            width: rawOffset.width.clamped(to: -maxTravel.width...maxTravel.width),
            height: rawOffset.height.clamped(to: -maxTravel.height...maxTravel.height)
        )
        // Keep the sky background larger than the viewport so panning/zooming
        // exposes more sky instead of revealing static screen edges. Clamp
        // background motion to the extra generated area so users never pan
        // past the end of the background.
        NightSkyBackgroundView(style: backgroundStyle, extendsIntoSafeArea: false)
            .frame(width: expandedSize.width, height: expandedSize.height)
            .scaleEffect(appliedScale)
            .offset(x: clampedOffset.width, y: clampedOffset.height)
            .frame(width: viewportSize.width, height: viewportSize.height)
            .offset(x: -safeAreaInsets.leading, y: -safeAreaInsets.top)
            .ignoresSafeArea()
            .clipped()
            .allowsHitTesting(false)
    }

    private var backgroundStyle: NightSkyBackgroundStyle {
        switch variant {
        case .focusStar:
            return .mySkyFocusStar
        case .legacy:
            return .mySkyLegacy
        case .aurora:
            return .mySkyAurora
        case .deepSpace:
            return .mySkyDeepSpace
        }
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
