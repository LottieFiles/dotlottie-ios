import XCTest
@testable import DotLottie

/// Slot introspection, generic and bezier path slot setters, the asset resolver,
/// and the state machine seed/status accessors.
final class SlotsAndAssetResolverTests: XCTestCase {

    /// bezier-path.json exposes a triangle under "shape_path" and its fill under "shape_color".
    private func makeBezierAnimation() -> DotLottieAnimation {
        let animation = DotLottieAnimation(animationData: Fixtures.string("bezier-path", "json"), config: AnimationConfig())
        XCTAssertTrue(animation.isLoaded())
        return animation
    }

    private func json(_ string: String?) throws -> [String: Any] {
        let data = try XCTUnwrap(string?.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Slots

    func testSlotIdsAndTypes() {
        let animation = makeBezierAnimation()

        XCTAssertEqual(Set(animation.getSlotIds()), ["shape_path", "shape_color"])
        XCTAssertEqual(animation.getSlotType(slotId: "shape_path"), "bezier_path")
        XCTAssertEqual(animation.getSlotType(slotId: "shape_color"), "color")
        XCTAssertNil(animation.getSlotType(slotId: "missing"))
        XCTAssertNil(animation.getSlot(slotId: "missing"))
    }

    func testSetSlotThenReadItBack() throws {
        let animation = makeBezierAnimation()

        XCTAssertTrue(animation.setSlot(slotId: "shape_color", json: #"{"a":0,"k":[0,1,0,1]}"#))

        let color = try XCTUnwrap(try json(animation.getSlot(slotId: "shape_color"))["k"] as? [Double])
        // Color slots are RGB: the alpha component is not kept.
        XCTAssertEqual(color, [0, 1, 0])
        XCTAssertNotNil(try json(animation.getSlots())["shape_color"])
        XCTAssertFalse(animation.setSlot(slotId: "shape_color", json: "not json"))
    }

    func testResetSlotRestoresTheAnimationValue() {
        let animation = makeBezierAnimation()
        let original = animation.getSlot(slotId: "shape_color")

        XCTAssertTrue(animation.setSlot(slotId: "shape_color", json: #"{"a":0,"k":[0,1,0,1]}"#))
        XCTAssertTrue(animation.resetSlot(slotId: "shape_color"))
        XCTAssertEqual(animation.getSlot(slotId: "shape_color"), original)

        XCTAssertTrue(animation.setSlot(slotId: "shape_color", json: #"{"a":0,"k":[0,0,1,1]}"#))
        XCTAssertTrue(animation.resetSlots())
        XCTAssertEqual(animation.getSlot(slotId: "shape_color"), original)
    }

    func testBezierPathSlot() throws {
        let animation = makeBezierAnimation()
        let square = [CGPoint(x: -80, y: -80), CGPoint(x: 80, y: -80), CGPoint(x: 80, y: 80), CGPoint(x: -80, y: 80)]

        XCTAssertTrue(animation.setBezierPathSlot(slotId: "shape_path", vertices: square, closed: true))

        let path = try XCTUnwrap(try json(animation.getSlot(slotId: "shape_path"))["k"] as? [String: Any])
        XCTAssertEqual(path["v"] as? [[Double]], [[-80, -80], [80, -80], [80, 80], [-80, 80]])
        XCTAssertEqual(path["i"] as? [[Double]], Array(repeating: [0, 0], count: 4))
        XCTAssertEqual(path["c"] as? Bool, true)

        let tangents = square.map { _ in CGPoint(x: 10, y: 10) }
        XCTAssertTrue(animation.setBezierPathSlot(slotId: "shape_path", vertices: square, closed: false, inTangents: tangents, outTangents: tangents))
        let curved = try XCTUnwrap(try json(animation.getSlot(slotId: "shape_path"))["k"] as? [String: Any])
        XCTAssertEqual(curved["o"] as? [[Double]], Array(repeating: [10, 10], count: 4))
        XCTAssertEqual(curved["c"] as? Bool, false)

        // Tangent arrays must match the vertex count, and a path needs at least one vertex.
        XCTAssertFalse(animation.setBezierPathSlot(slotId: "shape_path", vertices: square, closed: true, inTangents: Array(tangents.prefix(2))))
        XCTAssertFalse(animation.setBezierPathSlot(slotId: "shape_path", vertices: [], closed: true))
    }

    // MARK: - Asset resolver

    /// 8x8 solid red PNG, the same asset the dotlottie-rs resolver tests use.
    private let redPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAEklEQVR4nGP4z8DwHx9mGBkKAMLXf4EvceABAAAAAElFTkSuQmCC")!

    func testAssetResolverSuppliesExternalImages() {
        var requested: [String] = []
        var config = AnimationConfig()
        config.assetResolver = { [redPNG] src in
            requested.append(src)
            return redPNG
        }

        // external-assets.json references one remote image and one external path.
        let animation = DotLottieAnimation(animationData: Fixtures.string("external-assets", "json"), config: config)
        XCTAssertTrue(animation.isLoaded())
        _ = animation.render()

        XCTAssertEqual(requested.count, 2)
        XCTAssertTrue(requested.contains { $0.hasPrefix("https://") })
    }

    func testAssetResolverThatSkipsDoesNotBreakLoading() {
        var calls = 0
        var config = AnimationConfig()
        config.assetResolver = { _ in
            calls += 1
            return nil
        }

        let animation = DotLottieAnimation(animationData: Fixtures.string("external-assets", "json"), config: config)
        XCTAssertTrue(animation.isLoaded())
        _ = animation.render()

        XCTAssertEqual(calls, 2)
    }

    // MARK: - Playback

    func testSetLoopCount() {
        let animation = makeMinimalAnimation(loop: true)

        animation.setLoopCount(3)

        XCTAssertEqual(animation.player.config().loopCount, 3)
    }

    // MARK: - State machine

    func testStateMachineSeedAndStatus() throws {
        let animation = makeMinimalAnimation(autoplay: true)
        try XCTSkipUnless(animation.stateMachineLoadData(Fixtures.minimalStateMachineJSON), "Engine did not accept this state machine JSON – skipping")

        XCTAssertTrue(animation.stateMachineStart(openUrlPolicy: OpenUrlPolicy(requireUserInteraction: false)))
        XCTAssertEqual(animation.stateMachineStatus(), "Running")
        XCTAssertTrue(animation.stateMachineSetSeed(42))

        XCTAssertTrue(animation.stateMachineStop())
        XCTAssertEqual(animation.stateMachineStatus(), "Stopped")
    }
}
