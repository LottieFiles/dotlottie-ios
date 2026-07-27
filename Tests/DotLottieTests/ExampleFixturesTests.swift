import XCTest

@testable import DotLottie

/// Exercises the real animation assets shipped with the example app, loaded
/// through the public library API exactly as the examples load them. This is the
/// "do the examples actually work?" safety net: if an example animation stops
/// loading or rendering, one of these fails.
final class ExampleFixturesTests: XCTestCase {

    // MARK: - .lottie loading

    func testCoffeeLottieLoadsAndRenders() {
        let animation = DotLottieAnimation(
            dotLottieData: Fixtures.coffeeLottie, config: AnimationConfig(autoplay: true))
        XCTAssertTrue(waitUntilLoaded(animation), "coffee.lottie should load")
        XCTAssertFalse(animation.error())
        XCTAssertGreaterThan(animation.totalFrames(), 0)
        XCTAssertNotNil(animation.tick(dt: 0.1), "a loaded .lottie should produce a frame")
    }

    func testPigeonLottieLoadsAndRenders() {
        let animation = DotLottieAnimation(
            dotLottieData: Fixtures.pigeonLottie, config: AnimationConfig(autoplay: true))
        XCTAssertTrue(waitUntilLoaded(animation), "pigeon.lottie should load")
        XCTAssertGreaterThan(animation.totalFrames(), 0)
        XCTAssertNotNil(animation.tick(dt: 0.1))
    }

    func testThemingLottieLoadsAndExposesThemes() {
        let animation = DotLottieAnimation(
            dotLottieData: Fixtures.themingLottie, config: AnimationConfig())
        XCTAssertTrue(waitUntilLoaded(animation), "theming.lottie should load")

        let manifest = animation.manifest()
        XCTAssertNotNil(manifest, "theming.lottie should expose a manifest")
        let themeIds = Set((manifest?.themes ?? []).map(\.id))
        XCTAssertEqual(
            themeIds, ["Water", "air", "earth"], "manifest themes should match the fixture")
    }

    // MARK: - .json loading

    func testFlowJSONLoadsAndRenders() {
        let animation = DotLottieAnimation(
            animationData: Fixtures.flowJSON, config: AnimationConfig(autoplay: true))
        XCTAssertTrue(waitUntilLoaded(animation), "Flow.json should load")
        XCTAssertGreaterThan(animation.totalFrames(), 0)
        XCTAssertNotNil(animation.tick(dt: 0.1))
    }

    func testToggleJSONLoads() {
        let animation = DotLottieAnimation(
            animationData: Fixtures.toggleJSON, config: AnimationConfig())
        XCTAssertTrue(waitUntilLoaded(animation), "toggle.json should load")
        XCTAssertGreaterThan(animation.totalFrames(), 0)
    }

    // MARK: - lottieData: auto-detects JSON vs .lottie

    func testLottieDataInitDetectsDotLottie() {
        let animation = DotLottieAnimation(
            lottieData: Fixtures.coffeeLottie, config: AnimationConfig())
        XCTAssertTrue(waitUntilLoaded(animation), ".lottie bytes via lottieData: should load")
        XCTAssertGreaterThan(animation.totalFrames(), 0)
    }

    func testLottieDataInitDetectsJSON() {
        let jsonData = Data(Fixtures.flowJSON.utf8)
        let animation = DotLottieAnimation(lottieData: jsonData, config: AnimationConfig())
        XCTAssertTrue(waitUntilLoaded(animation), "JSON bytes via lottieData: should load")
        XCTAssertGreaterThan(animation.totalFrames(), 0)
    }
}
