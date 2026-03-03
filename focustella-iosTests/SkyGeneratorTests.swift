import XCTest
import CoreGraphics
@testable import focustella_ios

final class SkyGeneratorTests: XCTestCase {
    func testGenerateReturnsConfiguredStarCount() {
        var generator = SkyGenerator(
            config: .init(
                starCount: 40,
                constellationCount: 0,
                centerBiasSigma: 0.18,
                minStarDistance: 0.03
            )
        )

        let scene = generator.generate(seed: 12_345)
        XCTAssertEqual(scene.stars.count, 40)
    }

    func testGenerateStarsAreWithinClampedBounds() {
        var generator = SkyGenerator(
            config: .init(
                starCount: 40,
                constellationCount: 0,
                centerBiasSigma: 0.18,
                minStarDistance: 0.03
            )
        )

        let scene = generator.generate(seed: 12_345)

        for star in scene.stars {
            XCTAssertGreaterThanOrEqual(star.position.x, 0.05)
            XCTAssertLessThanOrEqual(star.position.x, 0.95)
            XCTAssertGreaterThanOrEqual(star.position.y, 0.05)
            XCTAssertLessThanOrEqual(star.position.y, 0.95)
        }
    }

    func testGenerateRespectsMinStarDistance() {
        let minDistance: CGFloat = 0.03
        var generator = SkyGenerator(
            config: .init(
                starCount: 40,
                constellationCount: 0,
                centerBiasSigma: 0.18,
                minStarDistance: minDistance
            )
        )

        let scene = generator.generate(seed: 12_345)

        for i in 0..<scene.stars.count {
            for j in (i + 1)..<scene.stars.count {
                let a = scene.stars[i].position
                let b = scene.stars[j].position
                let distance = hypot(a.x - b.x, a.y - b.y)
                XCTAssertGreaterThan(distance, minDistance)
            }
        }
    }

    func testGenerateIsDeterministicForSameSeed() {
        let config = SkyGenerator.Config(
            starCount: 40,
            constellationCount: 0,
            centerBiasSigma: 0.18,
            minStarDistance: 0.03
        )

        var generator1 = SkyGenerator(config: config)
        var generator2 = SkyGenerator(config: config)

        let scene1 = generator1.generate(seed: 777)
        let scene2 = generator2.generate(seed: 777)

        XCTAssertEqual(scene1.stars.map(\.position), scene2.stars.map(\.position))
        XCTAssertEqual(scene1.stars.map(\.color), scene2.stars.map(\.color))
    }
}
