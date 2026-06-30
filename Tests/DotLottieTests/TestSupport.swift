import XCTest
import Foundation
@testable import DotLottie

// MARK: - Shared Fixtures

/// Inline animation/state-machine data and access to the bundled example
/// animations, so every test file draws from one source of truth.
enum Fixtures {

    /// A minimal but valid Lottie animation (the "Bouncy Ball"): 512x512, fr=60, ip=0, op=120.
    static let minimalLottieJSON = """
    {"nm": "Bouncy Ball", "v": "5.5.2","ip": 0,"op": 120,"fr": 60,"w": 512,"h": 512,"layers": [{"ddd": 0,"ty": 4,"ind": 0,"st": 0,"ip": 0,"op": 120,"nm": "Layer","ks": {"a": {"a": 0,"k": [0, 0]},"p": {"a": 0,"k": [0, 0]},"s": {"a": 0,"k": [100, 100]},"r": {"a": 0,"k": 0},"o": {"a": 0,"k": 100}},"shapes": [{"ty": "gr","nm": "Ellipse Group", "it": [{"ty": "el","nm": "Ellipse","p": {"a": 0,"k": [204, 169]},"s": {"a": 0,"k": [153, 153]}},{"ty": "fl","nm": "Fill","o": {"a": 0,"k": 100,"sid": "ball_opacity"},"c": {"a": 0,"k": [0.71, 0.192, 0.278], "sid": "ball_color"},"r": 1},{"ty": "tr","a": {"a": 0,"k": [204, 169]},"p": {"a": 1,"sid": "ball_position", "k": [{"t": 0,"s": [235, 106],"h": 0,"o": {"x": [0.333],"y": [0]},"i": {"x": [1],"y": [1]}},{"t": 60,"s": [265, 441],"h": 0,"o": {"x": [0],"y": [0]},"i": {"x": [0.667],"y": [1]}},{"t": 120,"s": [235, 106]}]},"s": {"a": 1,"sid": "ball_scale", "k": [{"t": 55,"s": [100, 100],"h": 0,"o": {"x": [0],"y": [0]},"i": {"x": [1],"y": [1]}},{"t": 60,"s": [136, 59],"h": 0,"o": {"x": [0],"y": [0]},"i": {"x": [1],"y": [1]}},{"t": 65,"s": [100, 100]}]},"r": {"a": 0,"k": 0},"o": {"a": 0,"k": 100}}]}]}]}
    """

    /// A minimal inline state machine with one boolean, one numeric, and one string input.
    static let minimalStateMachineJSON = """
    {
            "id": "test-sm",
            "initial": "playing",
            "states": [
              {
                "type": "PlaybackState",
                "name": "playing",
                "animation": "",
                "loop": true,
                "autoplay": true,
                "segment": "bird",
                "transitions": []
              }
            ],
            "inputs": [
              {
                "name": "isActive",
                "type": "Boolean",
                "value": false
              },
              {
                "name": "count",
                "type": "Numeric",
                "value": 0
              },
                {
                "name": "word",
                "type": "String",
                "value": "initial"
                }
            ],
          "interactions": []
          }
    """

    // MARK: Bundled example animations (copied from Example/Example/Animations)

    /// Plain `.lottie` animation (manifest version "1", single animation, no themes).
    static var coffeeLottie: Data { data("coffee", "lottie") }

    /// `.lottie` carrying three themes: "Water", "air", "earth".
    static var themingLottie: Data { data("theming", "lottie") }

    /// `.lottie` carrying an embedded state machine ("pigeon_fsm").
    static var pigeonLottie: Data { data("pigeon", "lottie") }

    /// Plain Lottie `.json` used by the example app.
    static var flowJSON: String { string("Flow 1", "json") }

    /// Plain Lottie `.json` (toggle button).
    static var toggleJSON: String { string("toggle", "json") }

    /// State machine JSON with a single boolean input "OnOffSwitch".
    static var smToggleJSON: String { string("sm-toggle", "json") }

    static func data(_ name: String, _ ext: String) -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            fatalError("Missing test fixture: \(name).\(ext)")
        }
        return (try? Data(contentsOf: url)) ?? Data()
    }

    static func string(_ name: String, _ ext: String) -> String {
        String(decoding: data(name, ext), as: UTF8.self)
    }
}

// MARK: - Test helpers

extension XCTestCase {

    /// Builds an animation from the inline minimal Lottie JSON.
    func makeMinimalAnimation(
        autoplay: Bool = false,
        loop: Bool = false,
        speed: Float = 1,
        mode: Mode = .forward,
        segments: (Float, Float)? = nil,
        marker: String? = nil
    ) -> DotLottieAnimation {
        DotLottieAnimation(
            animationData: Fixtures.minimalLottieJSON,
            config: AnimationConfig(
                autoplay: autoplay,
                loop: loop,
                mode: mode,
                speed: speed,
                segments: segments,
                marker: marker
            )
        )
    }

    /// Some initializers (`dotLottieData:`, `lottieData:`, `webURL:`) load on a
    /// background `Task`, so loading can complete slightly after `init` returns.
    /// Spins briefly until the animation reports loaded (or errored), so tests are
    /// robust whether loading is synchronous or asynchronous.
    @discardableResult
    func waitUntilLoaded(_ animation: DotLottieAnimation, timeout: TimeInterval = 5.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !animation.isLoaded() && !animation.error() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        return animation.isLoaded()
    }
}
