import XCTest
@testable import DotLottie

/// Playback state machine: play / pause / stop and their `isPlaying`/`isPaused`/
/// `isStopped` reflections, plus `play(fromFrame:)` / `play(fromProgress:)`.
final class PlaybackTests: XCTestCase {

    // MARK: - Initial state

    func testNotPlayingWhenAutoplayDisabled() {
        let animation = makeMinimalAnimation(autoplay: false)
        XCTAssertTrue(animation.isLoaded())
        XCTAssertFalse(animation.isPlaying(), "autoplay:false should not start playing")
        XCTAssertFalse(animation.autoplay())
    }

    func testPlayingWhenAutoplayEnabled() {
        let animation = makeMinimalAnimation(autoplay: true)
        XCTAssertTrue(animation.isPlaying(), "autoplay:true should start playing")
        XCTAssertTrue(animation.autoplay())
    }

    // MARK: - Transitions

    func testPlayPauseStopCycle() {
        let animation = makeMinimalAnimation(autoplay: false)

        XCTAssertTrue(animation.play())
        XCTAssertTrue(animation.isPlaying())
        XCTAssertFalse(animation.isPaused())
        XCTAssertFalse(animation.isStopped())

        XCTAssertTrue(animation.pause())
        XCTAssertTrue(animation.isPaused())
        XCTAssertFalse(animation.isPlaying())

        XCTAssertTrue(animation.stop())
        XCTAssertTrue(animation.isStopped())
        XCTAssertFalse(animation.isPlaying())
        XCTAssertFalse(animation.isPaused())
    }

    func testPlayAfterStopRestarts() {
        let animation = makeMinimalAnimation(autoplay: true)
        XCTAssertTrue(animation.stop())
        XCTAssertTrue(animation.isStopped())
        XCTAssertTrue(animation.play())
        XCTAssertTrue(animation.isPlaying())
    }

    func testPlayAfterPauseResumes() {
        let animation = makeMinimalAnimation(autoplay: true)
        XCTAssertTrue(animation.pause())
        XCTAssertTrue(animation.isPaused())
        XCTAssertTrue(animation.play())
        XCTAssertTrue(animation.isPlaying())
    }

    func testPlayOnUnloadedAnimationReturnsFalse() {
        let animation = DotLottieAnimation(animationData: "{ invalid }", config: AnimationConfig())
        XCTAssertFalse(animation.isLoaded())
        XCTAssertFalse(animation.play(), "play() on an unloaded animation should fail")
        XCTAssertFalse(animation.isPlaying())
    }

    // MARK: - play(fromFrame:) / play(fromProgress:)

    func testPlayFromFrameSeeksAndPlays() {
        let animation = makeMinimalAnimation(autoplay: false)
        let target: Float = 30
        XCTAssertTrue(animation.play(fromFrame: target))
        XCTAssertTrue(animation.isPlaying())
        XCTAssertEqual(animation.currentFrame(), target, accuracy: 1.0)
    }

    func testPlayFromProgressSeeksToMidpoint() {
        let animation = makeMinimalAnimation(autoplay: false)
        XCTAssertTrue(animation.play(fromProgress: 0.5))
        XCTAssertTrue(animation.isPlaying())
        // 0.5 * 120 frames == 60
        XCTAssertEqual(animation.currentFrame(), animation.totalFrames() * 0.5, accuracy: 2.0)
    }

    /// `play(fromProgress:)` accepts the exact boundaries 0 and 1.
    func testPlayFromProgressAllowsBoundaries() {
        let fromStart = makeMinimalAnimation(autoplay: false)
        XCTAssertTrue(fromStart.play(fromProgress: 0.0), "play(fromProgress: 0) should play from the start")
        XCTAssertTrue(fromStart.isPlaying())

        let fromEnd = makeMinimalAnimation(autoplay: false)
        XCTAssertTrue(fromEnd.play(fromProgress: 1.0), "play(fromProgress: 1) should be accepted")
        XCTAssertTrue(fromEnd.isPlaying())
    }

    func testPlayFromProgressRejectsOutOfRange() {
        let animation = makeMinimalAnimation(autoplay: false)
        XCTAssertFalse(animation.play(fromProgress: -0.1))
        XCTAssertFalse(animation.play(fromProgress: 1.5))
    }

    // MARK: - Loop

    func testLoopReflectsConfig() {
        let looping = makeMinimalAnimation(loop: true)
        XCTAssertTrue(looping.loop())

        let once = makeMinimalAnimation(loop: false)
        XCTAssertFalse(once.loop())
    }

    func testSetLoopTogglesValue() {
        let animation = makeMinimalAnimation(loop: false)
        animation.setLoop(loop: true)
        XCTAssertTrue(animation.loop())
        animation.setLoop(loop: false)
        XCTAssertFalse(animation.loop())
    }

    // MARK: - Autoplay setter

    func testSetAutoplayUpdatesValue() {
        let animation = makeMinimalAnimation(autoplay: false)
        animation.setAutoplay(autoplay: true)
        XCTAssertTrue(animation.autoplay())
    }
}
