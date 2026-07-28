import XCTest
@testable import DotLottie

/// Internal parsing helpers. `getAnimationFramerate` is live (it drives the
/// published `framerate`); the width/height + URL helpers are currently unused
/// but tested to lock in their documented contracts.
final class UtilsTests: XCTestCase {

    // MARK: - getAnimationFramerate

    func testFramerateInteger() throws {
        XCTAssertEqual(try getAnimationFramerate(animationData: Fixtures.minimalLottieJSON), 60)
    }

    func testFramerateFractionalRoundsToNearest() throws {
        // Regression: fractional framerates used to throw and force a 30fps fallback.
        XCTAssertEqual(try getAnimationFramerate(animationData: #"{"fr":59.94}"#), 60)
        XCTAssertEqual(try getAnimationFramerate(animationData: #"{"fr":29.97}"#), 30)
        XCTAssertEqual(try getAnimationFramerate(animationData: #"{"fr":23.976}"#), 24)
    }

    func testFramerateMissingThrows() {
        XCTAssertThrowsError(try getAnimationFramerate(animationData: #"{"w":1,"h":1}"#))
    }

    /// The published `framerate` should reflect a fractional fps (drives the Metal
    /// view's `preferredFramesPerSecond` and the SwiftUI render cadence).
    func testLiveFramerateReflectsFractionalFps() {
        let json = #"{"nm":"x","v":"5.5.2","fr":59.94,"ip":0,"op":60,"w":64,"h":64,"layers":[]}"#
        let animation = DotLottieAnimation(animationData: json, config: AnimationConfig())
        // `framerate` is published via DispatchQueue.main.async after load; spin briefly.
        let deadline = Date().addingTimeInterval(2.0)
        while animation.framerate == 30 && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertEqual(animation.framerate, 60, "59.94fps should be detected as 60, not the 30 default")
    }

    // MARK: - getAnimationWidthHeight

    func testWidthHeightOrderMatchesContract() throws {
        // Documented contract is (width, height).
        let (w, h) = try getAnimationWidthHeight(animationData: #"{"w":300,"h":200}"#)
        XCTAssertEqual(w, 300, "first element should be width")
        XCTAssertEqual(h, 200, "second element should be height")
    }

    func testWidthHeightMissingReturnsZero() throws {
        // No w/h keys → the parser falls back to (0, 0) rather than throwing.
        let (w, h) = try getAnimationWidthHeight(animationData: #"{"fr":30}"#)
        XCTAssertEqual(w, 0)
        XCTAssertEqual(h, 0)
    }

    // MARK: - verifyUrlType

    func testVerifyUrlAcceptsKnownExtensions() {
        XCTAssertNoThrow(try verifyUrlType(url: "https://example.com/a.json"))
        XCTAssertNoThrow(try verifyUrlType(url: "https://example.com/a.lottie"))
        XCTAssertNoThrow(try verifyUrlType(url: "https://example.com/a.lot"))
        XCTAssertNoThrow(try verifyUrlType(url: "https://example.com/A.LOTTIE"), "extension check is case-insensitive")
    }

    func testVerifyUrlRejectsUnknownExtension() {
        XCTAssertThrowsError(try verifyUrlType(url: "https://example.com/a.gif"))
        XCTAssertThrowsError(try verifyUrlType(url: "https://example.com/noextension"))
    }
}
