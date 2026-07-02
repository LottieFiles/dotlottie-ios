import XCTest
import Metal
@testable import DotLottie

/// Regression guards for the retain-cycle fixes in the view/coordinator/player
/// layer. Each builds a view inside an `autoreleasepool` and asserts a `weak`
/// reference is nil afterwards — if a cycle is reintroduced, the view outlives
/// the pool and the reference stays non-nil.
final class MemoryManagementTests: XCTestCase {

#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
    /// Regression guard for the retain-cycle fixes in `Coordinator` (it now holds
    /// the view-model instead of the view) and in the `$framerate` sink (`[weak self]`).
    /// The view must deallocate even while its view-model is kept alive — the exact
    /// cycle that used to leak was `view → coordinator → view` (and the sink capturing
    /// `self` strongly via `cancellableBag`). If either regresses, the view survives
    /// the `autoreleasepool` and `weakView` stays non-nil.
    func testAnimationViewDeallocatesWhileViewModelStaysAlive() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "No Metal device available – skipping")

        let viewModel = makeMinimalAnimation() // deliberately kept alive for the whole test
        weak var weakView: DotLottieAnimationView?

        autoreleasepool {
            let view = DotLottieAnimationView(dotLottieViewModel: viewModel)
            weakView = view
        }

        XCTAssertNil(
            weakView,
            "DotLottieAnimationView leaked – a view/coordinator or $framerate-sink retain cycle was reintroduced"
        )
    }
#endif

#if os(iOS)
    /// Regression guard for the CADisplayLink retain-cycle fix (`DisplayLinkProxy`).
    /// `init` calls `startDisplayLink()`; with a strong `target: self` the run loop
    /// retains the link which retains the view, so the view can never deallocate.
    /// iOS-only — the macOS render loop uses a `DispatchSource` timer with `[weak self]`.
    func testWebGPUViewDeallocatesAfterStartingDisplayLink() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "No Metal device available – skipping")

        weak var weakView: DotLottieWebGPUView?

        autoreleasepool {
            let view = DotLottieWebGPUView() // init → startDisplayLink()
            weakView = view
        }

        XCTAssertNil(
            weakView,
            "DotLottieWebGPUView leaked – the CADisplayLink retain cycle was reintroduced"
        )
    }
#endif
}
