import XCTest
@testable import DotLottie

/// Segments, markers, themes, slots and manifest — the content/metadata surface.
final class SegmentsMarkersThemesTests: XCTestCase {

    // MARK: - Segments

    func testDefaultSegmentSpansWholeAnimation() {
        let animation = makeMinimalAnimation()
        let (start, end) = animation.segments()
        XCTAssertEqual(start, 0, accuracy: 0.5)
        XCTAssertEqual(end, animation.totalFrames() - 1, accuracy: 1.0)
    }

    /// Regression test: `segments()` used to index `segment[0]` on an empty array
    /// and crash when the animation was not loaded. It must now return (0, 0).
    func testSegmentsOnUnloadedAnimationDoesNotCrash() {
        let animation = DotLottieAnimation(animationData: "{ invalid }", config: AnimationConfig())
        XCTAssertFalse(animation.isLoaded())
        let (start, end) = animation.segments()
        XCTAssertEqual(start, 0)
        XCTAssertEqual(end, 0)
    }

    func testSetSegmentsRoundTrips() {
        let animation = makeMinimalAnimation()
        animation.setSegments(segments: (10, 50))
        let (start, end) = animation.segments()
        XCTAssertEqual(start, 10, accuracy: 0.5)
        XCTAssertEqual(end, 50, accuracy: 0.5)
    }

    // MARK: - Markers

    func testMinimalAnimationHasNoMarkers() {
        let animation = makeMinimalAnimation()
        XCTAssertTrue(animation.markers().isEmpty, "minimal fixture defines no markers")
    }

    func testMarkersAreReadableFromFixtures() {
        // Markers depend on the asset; just assert the call is safe and returns an array.
        let animation = DotLottieAnimation(dotLottieData: Fixtures.coffeeLottie, config: AnimationConfig())
        _ = waitUntilLoaded(animation)
        XCTAssertNotNil(animation.markers())
    }

    // MARK: - Themes

    func testManifestExposesThemes() {
        let animation = DotLottieAnimation(dotLottieData: Fixtures.themingLottie, config: AnimationConfig())
        _ = waitUntilLoaded(animation)
        let themes = animation.manifest()?.themes ?? []
        XCTAssertEqual(Set(themes.map(\.id)), ["Water", "air", "earth"])
    }

    func testSetThemeActivatesTheme() {
        let animation = DotLottieAnimation(dotLottieData: Fixtures.themingLottie, config: AnimationConfig())
        _ = waitUntilLoaded(animation)
        XCTAssertTrue(animation.setTheme("Water"), "Water is a valid theme in theming.lottie")
        XCTAssertEqual(animation.activeThemeId(), "Water")
    }

    func testResetThemeClearsActiveTheme() {
        let animation = DotLottieAnimation(dotLottieData: Fixtures.themingLottie, config: AnimationConfig())
        _ = waitUntilLoaded(animation)
        _ = animation.setTheme("Water")
        XCTAssertTrue(animation.resetTheme())
        XCTAssertEqual(animation.activeThemeId(), "")
    }

    func testSetThemeWithInvalidIdFails() {
        let animation = DotLottieAnimation(dotLottieData: Fixtures.themingLottie, config: AnimationConfig())
        _ = waitUntilLoaded(animation)
        XCTAssertFalse(animation.setTheme("does-not-exist"))
    }

    // MARK: - Manifest

    func testManifestForPlainLottie() {
        let animation = DotLottieAnimation(dotLottieData: Fixtures.coffeeLottie, config: AnimationConfig())
        _ = waitUntilLoaded(animation)
        let manifest = animation.manifest()
        XCTAssertNotNil(manifest)
        XCTAssertFalse(manifest?.animations.isEmpty ?? true, "coffee.lottie has at least one animation")
    }

    func testManifestNilForRawJSON() {
        // A raw .json animation has no dotLottie manifest.
        let animation = makeMinimalAnimation()
        XCTAssertNil(animation.manifest())
    }
}
