import XCTest
@testable import DotLottie

/// Core smoke + rendering pipeline for `DotLottieAnimation`. Playback, frames,
/// config, segments/markers/themes, state machine and utils each have their own
/// focused test file; this one covers load → render → resize.
final class DotLottieTests: XCTestCase {

    // MARK: - Loading

    func testAnimationLoads() {
        let animation = makeMinimalAnimation()
        XCTAssertTrue(animation.isLoaded(), "Animation should be loaded after init")
        XCTAssertFalse(animation.error(), "Animation should not have an error")
        XCTAssertGreaterThan(animation.totalFrames(), 0, "Animation should have at least one frame")
    }

    func testInvalidAnimationDataSetsErrorFlag() {
        let animation = DotLottieAnimation(animationData: "{ not valid lottie }", config: AnimationConfig())
        XCTAssertTrue(animation.error(), "Invalid animation data should set the error flag")
        XCTAssertFalse(animation.isLoaded())
    }

    func testEmptyAnimationDataSetsErrorFlag() {
        let animation = DotLottieAnimation(animationData: "", config: AnimationConfig())
        XCTAssertFalse(animation.isLoaded())
    }

    // MARK: - Rendering pipeline

    /// Full pipeline: load → tick → CGImage.
    func testTickReturnsImageWhenLoaded() {
        let animation = makeMinimalAnimation(autoplay: true)
        XCTAssertTrue(animation.isLoaded())
        XCTAssertNotNil(animation.tick(dt: 0.1), "tick() should return a CGImage for a loaded animation")
    }

    func testTickReturnsNilWhenNotLoaded() {
        let animation = DotLottieAnimation(animationData: "{ not valid }", config: AnimationConfig(autoplay: true))
        XCTAssertFalse(animation.isLoaded())
        XCTAssertNil(animation.tick(dt: 0.1), "tick() should return nil when animation is not loaded")
    }

    func testFrameImageRendersCurrentFrameWithoutAdvancing() {
        let animation = makeMinimalAnimation(autoplay: false)
        XCTAssertTrue(animation.setFrame(frame: 20))
        let before = animation.currentFrame()
        XCTAssertNotNil(animation.frameImage(), "frameImage() should render the current frame")
        XCTAssertEqual(animation.currentFrame(), before, accuracy: 0.001, "frameImage() must not advance time")
    }

    /// `render()` reports whether a new frame was drawn: true after the frame
    /// changes, false on a redundant call with no change.
    func testRenderReflectsFrameChange() {
        let animation = makeMinimalAnimation(autoplay: false)
        XCTAssertTrue(animation.setFrame(frame: 30))
        XCTAssertTrue(animation.render(), "render() should report true after the frame changed")
        XCTAssertFalse(animation.render(), "a second render() with no change should report false")
    }

    func testRenderFalseWhenNotLoaded() {
        let animation = DotLottieAnimation(animationData: "{ bad }", config: AnimationConfig())
        XCTAssertFalse(animation.render())
    }

    // MARK: - Resize

    func testResizeUpdatesModelDimensions() {
        let animation = makeMinimalAnimation()
        animation.resize(width: 256, height: 128)
        XCTAssertEqual(animation.animationModel.width, 256)
        XCTAssertEqual(animation.animationModel.height, 128)
        XCTAssertFalse(animation.error(), "a valid resize should not set the error flag")
        XCTAssertNotNil(animation.tick(dt: 0.1), "animation should still render after resize")
    }

    func testResizeToZeroSetsErrorFlag() {
        let animation = makeMinimalAnimation()
        animation.resize(width: 0, height: 0)
        XCTAssertTrue(animation.error(), "resizing to an invalid (zero) size should set the error flag")
    }

    // MARK: - Custom dimensions from config

    func testCustomWidthHeightFromConfig() {
        let animation = DotLottieAnimation(
            animationData: Fixtures.minimalLottieJSON,
            config: AnimationConfig(width: 128, height: 64)
        )
        XCTAssertEqual(animation.animationModel.width, 128)
        XCTAssertEqual(animation.animationModel.height, 64)
        XCTAssertTrue(animation.sizeOverrideActive)
    }
}
