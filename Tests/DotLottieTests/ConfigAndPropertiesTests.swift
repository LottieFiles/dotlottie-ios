import XCTest
@testable import DotLottie

/// `AnimationConfig` defaults plus the config-backed getters/setters on
/// `DotLottieAnimation` (mode, speed, interpolation, layout, duration).
final class ConfigAndPropertiesTests: XCTestCase {

    // MARK: - AnimationConfig defaults

    func testAnimationConfigDefaults() {
        let config = AnimationConfig()
        XCTAssertEqual(config.autoplay, false)
        XCTAssertEqual(config.loop, false)
        XCTAssertEqual(config.loopCount, 0)
        XCTAssertEqual(config.mode, .forward)
        XCTAssertEqual(config.speed, 1)
        XCTAssertEqual(config.useFrameInterpolation, false)
        XCTAssertNil(config.segments)
    }

    // MARK: - Speed

    func testDefaultSpeedIsOne() {
        XCTAssertEqual(makeMinimalAnimation().speed(), 1.0, accuracy: 0.001)
    }

    func testSetSpeedRoundTrips() {
        let animation = makeMinimalAnimation()
        animation.setSpeed(speed: 2.5)
        XCTAssertEqual(animation.speed(), 2.5, accuracy: 0.001)
        animation.setSpeed(speed: 0.5)
        XCTAssertEqual(animation.speed(), 0.5, accuracy: 0.001)
    }

    func testSpeedFromConfig() {
        let animation = makeMinimalAnimation(speed: 3.0)
        XCTAssertEqual(animation.speed(), 3.0, accuracy: 0.001)
    }

    // MARK: - Mode

    func testDefaultModeIsForward() {
        XCTAssertEqual(makeMinimalAnimation().mode(), .forward)
    }

    func testSetModeRoundTrips() {
        let animation = makeMinimalAnimation()
        for mode in [Mode.reverse, .bounce, .reverseBounce, .forward] {
            animation.setMode(mode: mode)
            XCTAssertEqual(animation.mode(), mode, "mode should round-trip through config")
        }
    }

    func testModeFromConfig() {
        XCTAssertEqual(makeMinimalAnimation(mode: .bounce).mode(), .bounce)
    }

    // MARK: - Frame interpolation

    func testDefaultFrameInterpolationIsFalse() {
        XCTAssertFalse(makeMinimalAnimation().useFrameInterpolation())
    }

    func testSetFrameInterpolationRoundTrips() {
        let animation = makeMinimalAnimation()
        animation.setFrameInterpolation(true)
        XCTAssertTrue(animation.useFrameInterpolation())
        animation.setFrameInterpolation(false)
        XCTAssertFalse(animation.useFrameInterpolation())
    }

    // MARK: - Layout

    func testDefaultLayoutIsContainCentered() {
        let layout = makeMinimalAnimation().layout()
        XCTAssertEqual(layout.fit, .contain)
        XCTAssertEqual(layout.alignX, 0.5, accuracy: 0.001)
        XCTAssertEqual(layout.alignY, 0.5, accuracy: 0.001)
    }

    func testSetLayoutRoundTrips() {
        let animation = makeMinimalAnimation()
        animation.setLayout(layout: Layout(fit: .cover, alignX: 0.0, alignY: 1.0))
        let layout = animation.layout()
        XCTAssertEqual(layout.fit, .cover)
        XCTAssertEqual(layout.alignX, 0.0, accuracy: 0.001)
        XCTAssertEqual(layout.alignY, 1.0, accuracy: 0.001)
    }

    // MARK: - Duration

    /// `duration()` is reported in **milliseconds** at this layer (120 frames @
    /// 60fps == 2000.0) — this is the documented unit. Consumers that want seconds
    /// (`DotLottiePlayerUIView.duration`, the example's AnimationInfoView) divide by
    /// 1000. Pinned so the unit cannot change silently.
    func testDurationIsReportedInMilliseconds() {
        let animation = makeMinimalAnimation()
        XCTAssertEqual(animation.duration(), 2000, accuracy: 2.0,
                       "minimal fixture: 120 frames @ 60fps == 2000ms")
    }

    func testDurationConsistentWithFramesAndFps() {
        // duration(ms) ≈ totalFrames / fps * 1000; with fps=60 → frames * 16.667
        let animation = makeMinimalAnimation()
        let expectedMs = animation.totalFrames() / 60.0 * 1000.0
        XCTAssertEqual(animation.duration(), expectedMs, accuracy: 20.0)
    }

    // MARK: - Error surface

    func testErrorFlagAndMessageForInvalidData() {
        let animation = DotLottieAnimation(animationData: "{ not lottie }", config: AnimationConfig())
        XCTAssertTrue(animation.error())
        XCTAssertFalse(animation.isLoaded())
    }

    func testNoErrorForValidData() {
        let animation = makeMinimalAnimation()
        XCTAssertFalse(animation.error())
        XCTAssertEqual(animation.errorMessage(), "")
    }
}
