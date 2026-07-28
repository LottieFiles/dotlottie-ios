import XCTest
@testable import DotLottie

/// Frame & progress getters/setters, including boundary behavior.
final class FrameProgressTests: XCTestCase {

    func testTotalFramesIsPositive() {
        let animation = makeMinimalAnimation()
        XCTAssertEqual(animation.totalFrames(), 120, accuracy: 1.0, "minimal fixture is op=120")
    }

    func testCurrentFrameStartsAtZero() {
        let animation = makeMinimalAnimation(autoplay: false)
        XCTAssertEqual(animation.currentFrame(), 0, accuracy: 0.5)
    }

    func testSetFrameUpdatesCurrentFrame() {
        let animation = makeMinimalAnimation(autoplay: false)
        XCTAssertTrue(animation.setFrame(frame: 42))
        XCTAssertEqual(animation.currentFrame(), 42, accuracy: 0.5)
    }

    func testSetFrameToSameFrameReturnsFalse() {
        let animation = makeMinimalAnimation(autoplay: false)
        XCTAssertTrue(animation.setFrame(frame: 10))
        XCTAssertFalse(animation.setFrame(frame: 10), "setting the current frame again should be a no-op (false)")
    }

    // MARK: - Progress

    func testCurrentProgressTracksFrame() {
        let animation = makeMinimalAnimation(autoplay: false)
        XCTAssertTrue(animation.setFrame(frame: animation.totalFrames() * 0.5))
        XCTAssertEqual(animation.currentProgress(), 0.5, accuracy: 0.02)
    }

    func testSetProgressSeeksToFrame() {
        let animation = makeMinimalAnimation(autoplay: false)
        XCTAssertTrue(animation.setProgress(progress: 0.25))
        XCTAssertEqual(animation.currentFrame(), animation.totalFrames() * 0.25, accuracy: 2.0)
    }

    /// `setProgress` accepts the exact boundaries 0 and 1, seeking to the first /
    /// last frame. (Progress 1.0 clamps to `totalFrames - 1`, the last valid frame.)
    func testSetProgressAllowsBoundaries() {
        let animation = makeMinimalAnimation(autoplay: false)
        // Seek to the middle first so 0.0 is a real change (setFrame is a no-op when
        // the target equals the current frame).
        XCTAssertTrue(animation.setProgress(progress: 0.5))

        XCTAssertTrue(animation.setProgress(progress: 0.0), "progress 0.0 should seek to the start")
        XCTAssertEqual(animation.currentFrame(), 0, accuracy: 0.5)

        XCTAssertTrue(animation.setProgress(progress: 1.0), "progress 1.0 should seek to the end")
        XCTAssertEqual(animation.currentFrame(), animation.totalFrames() - 1, accuracy: 1.0)
    }

    func testSetProgressRejectsOutOfRange() {
        let animation = makeMinimalAnimation(autoplay: false)
        XCTAssertFalse(animation.setProgress(progress: -0.5))
        XCTAssertFalse(animation.setProgress(progress: 1.5))
    }
}
