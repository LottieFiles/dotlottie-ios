#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
import XCTest
@testable import DotLottie

/// The high-level `DotLottiePlayerUIView` wrapper (UIView/NSView). Covers the
/// property bridge, play-range helpers, and marker lookups. Runs headlessly.
final class LottiePlayerUIViewTests: XCTestCase {

    private func makeView(autoplay: Bool = false) -> DotLottiePlayerUIView {
        let animation = DotLottieAnimation(
            animationData: Fixtures.minimalLottieJSON,
            config: AnimationConfig(autoplay: autoplay)
        )
        return DotLottiePlayerUIView(dotLottieAnimation: animation)
    }

    // MARK: - Property bridge

    func testExposesAnimationProperties() {
        let view = makeView()
        XCTAssertEqual(view.totalFrames, 120, accuracy: 1.0)
        XCTAssertEqual(view.animationSpeed, 1.0, accuracy: 0.001)
    }

    func testSpeedGetterSetter() {
        let view = makeView()
        view.animationSpeed = 2.0
        XCTAssertEqual(view.animationSpeed, 2.0, accuracy: 0.001)
    }

    func testLoopModeGetterSetter() {
        let view = makeView()
        view.loopMode = .loop
        XCTAssertEqual(view.loopMode, .loop)
        view.loopMode = .playOnce
        XCTAssertEqual(view.loopMode, .playOnce)
    }

    func testModeGetterSetter() {
        let view = makeView()
        view.mode = .reverse
        XCTAssertEqual(view.mode, .reverse)
    }

    func testUseFrameInterpolationGetterSetter() {
        let view = makeView()
        view.useFrameInterpolation = true
        XCTAssertTrue(view.useFrameInterpolation)
    }

    func testCurrentFrameGetterSetter() {
        let view = makeView()
        view.currentFrame = 30
        XCTAssertEqual(view.currentFrame, 30, accuracy: 0.5)
    }

    func testCurrentProgressSetterSeeksToMidpoint() {
        let view = makeView()
        view.currentProgress = 0.5
        XCTAssertEqual(view.currentProgress, 0.5, accuracy: 0.02)
        XCTAssertEqual(view.currentFrame, 60, accuracy: 2.0)
    }

    /// `currentProgress = 0` seeks back to the start (the boundary is now accepted).
    func testCurrentProgressZeroSeeksToStart() {
        let view = makeView()
        view.currentProgress = 0.5
        view.currentProgress = 0.0
        XCTAssertEqual(view.currentFrame, 0, accuracy: 0.5, "currentProgress = 0 should seek to the start")
    }

    func testSegmentsGetterSetter() {
        let view = makeView()
        view.segments = (10, 50)
        let segs = view.segments
        XCTAssertEqual(segs?.0 ?? -1, 10, accuracy: 0.5)
        XCTAssertEqual(segs?.1 ?? -1, 50, accuracy: 0.5)
    }

    // MARK: - Playback passthrough

    func testPlayPauseStop() {
        let view = makeView()
        XCTAssertTrue(view.play())
        XCTAssertTrue(view.isAnimationPlaying)
        XCTAssertTrue(view.pause())
        XCTAssertTrue(view.isAnimationPaused)
        XCTAssertTrue(view.stop())
        XCTAssertTrue(view.isAnimationStopped)
    }

    func testPlayFromProgressRangeSetsSegments() {
        let view = makeView()
        XCTAssertTrue(view.play(fromProgress: 0.2, toProgress: 0.8))
        XCTAssertTrue(view.isAnimationPlaying)
        let segs = view.segments
        XCTAssertEqual(segs?.0 ?? -1, 0.2 * 120, accuracy: 2.0)
        XCTAssertEqual(segs?.1 ?? -1, 0.8 * 120, accuracy: 2.0)
    }

    func testPlayFromFrameRangeSetsSegments() {
        let view = makeView()
        XCTAssertTrue(view.play(fromFrame: 24, toFrame: 96))
        let segs = view.segments
        XCTAssertEqual(segs?.0 ?? -1, 24, accuracy: 0.5)
        XCTAssertEqual(segs?.1 ?? -1, 96, accuracy: 0.5)
    }

    func testPlayMarkerNotFoundReturnsFalse() {
        let view = makeView()
        XCTAssertFalse(view.play(marker: "does-not-exist"))
    }

    // MARK: - Markers / manifest

    func testMinimalAnimationHasNoMarkersOrManifest() {
        let view = makeView()
        XCTAssertTrue(view.markers().isEmpty)
        XCTAssertNil(view.manifest())
        XCTAssertFalse(view.isStateMachine())
    }

    func testMarkerLookupsReturnNilWhenMissing() {
        let view = makeView()
        XCTAssertNil(view.progressTime(forMarker: "nope"))
        XCTAssertNil(view.frameTime(forMarker: "nope"))
        XCTAssertNil(view.durationFrameTime(forMarker: "nope"))
    }

    // MARK: - No-animation defaults

    func testNilAnimationReturnsSafeDefaults() {
        let view = DotLottiePlayerUIView()
        XCTAssertEqual(view.totalFrames, 0)
        XCTAssertFalse(view.isAnimationPlaying)
        XCTAssertFalse(view.play())
        XCTAssertTrue(view.markers().isEmpty)
        XCTAssertNil(view.manifest())
    }

    // MARK: - Duration units

    /// `DotLottiePlayerUIView.duration` is a `TimeInterval` in seconds: a 2-second
    /// animation (120 frames @ 60fps) reports 2.0, having converted the core's
    /// millisecond value.
    func testDurationReportedInSeconds() {
        let view = makeView()
        XCTAssertEqual(view.duration, 2.0, accuracy: 0.01,
                       "TimeInterval duration should be in seconds")
    }
}
#endif
