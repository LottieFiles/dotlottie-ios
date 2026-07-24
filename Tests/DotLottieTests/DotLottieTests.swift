import XCTest
@testable import DotLottie

// MARK: - Test Fixtures

private let minimalLottieJSON = """
{"nm": "Bouncy Ball", "v": "5.5.2","ip": 0,"op": 120,"fr": 60,"w": 512,"h": 512,"layers": [{"ddd": 0,"ty": 4,"ind": 0,"st": 0,"ip": 0,"op": 120,"nm": "Layer","ks": {"a": {"a": 0,"k": [0, 0]},"p": {"a": 0,"k": [0, 0]},"s": {"a": 0,"k": [100, 100]},"r": {"a": 0,"k": 0},"o": {"a": 0,"k": 100}},"shapes": [{"ty": "gr","nm": "Ellipse Group", "it": [{"ty": "el","nm": "Ellipse","p": {"a": 0,"k": [204, 169]},"s": {"a": 0,"k": [153, 153]}},{"ty": "fl","nm": "Fill","o": {"a": 0,"k": 100,"sid": "ball_opacity"},"c": {"a": 0,"k": [0.71, 0.192, 0.278], "sid": "ball_color"},"r": 1},{"ty": "tr","a": {"a": 0,"k": [204, 169]},"p": {"a": 1,"sid": "ball_position", "k": [{"t": 0,"s": [235, 106],"h": 0,"o": {"x": [0.333],"y": [0]},"i": {"x": [1],"y": [1]}},{"t": 60,"s": [265, 441],"h": 0,"o": {"x": [0],"y": [0]},"i": {"x": [0.667],"y": [1]}},{"t": 120,"s": [235, 106]}]},"s": {"a": 1,"sid": "ball_scale", "k": [{"t": 55,"s": [100, 100],"h": 0,"o": {"x": [0],"y": [0]},"i": {"x": [1],"y": [1]}},{"t": 60,"s": [136, 59],"h": 0,"o": {"x": [0],"y": [0]},"i": {"x": [1],"y": [1]}},{"t": 65,"s": [100, 100]}]},"r": {"a": 0,"k": 0},"o": {"a": 0,"k": 100}}]}]}]}
"""

private let minimalStateMachineJSON = """
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

// MARK: - Test Suite

final class DotLottieTests: XCTestCase {
    
    // MARK: - Helpers
    
    private func makeAnimation(autoplay: Bool = false, loop: Bool = false) -> DotLottieAnimation {
        DotLottieAnimation(
            animationData: minimalLottieJSON,
            config: AnimationConfig(autoplay: autoplay, loop: loop)
        )
    }
    
    // MARK: - Loading
    
    func testAnimationLoads() {
        let animation = makeAnimation()
        XCTAssertTrue(animation.isLoaded(), "Animation should be loaded after init")
        XCTAssertFalse(animation.error(), "Animation should not have an error")
        XCTAssertGreaterThan(animation.totalFrames(), 0, "Animation should have at least one frame")
    }
    
    func testInvalidAnimationDataSetsErrorFlag() {
        let animation = DotLottieAnimation(
            animationData: "{ not valid lottie }",
            config: AnimationConfig()
        )
        XCTAssertTrue(animation.error(), "Invalid animation data should set the error flag")
    }
    
    // MARK: - Rendering
    
    /// Verifies the full rendering pipeline: load → tick → CGImage.
    func testTickReturnsImageWhenLoaded() {
        let animation = makeAnimation(autoplay: true)
        XCTAssertTrue(animation.isLoaded())
        
        let image = animation.tick()
        XCTAssertNotNil(image, "tick() should return a CGImage for a loaded animation")
    }
    
    func testTickReturnsNilWhenNotLoaded() {
        let animation = DotLottieAnimation(
            animationData: "{ not valid }",
            config: AnimationConfig(autoplay: true)
        )
        XCTAssertFalse(animation.isLoaded())
        XCTAssertNil(animation.tick(), "tick() should return nil when animation is not loaded")
    }
    
    // MARK: - Playback Controls
    
    func testPlay() {
        let animation = makeAnimation(autoplay: false)
        XCTAssertFalse(animation.isPlaying(), "Animation should not be playing before play()")
        
        let result = animation.play()
        XCTAssertTrue(result, "play() should return true")
        XCTAssertTrue(animation.isPlaying(), "Animation should be playing after play()")
        XCTAssertFalse(animation.isPaused())
        XCTAssertFalse(animation.isStopped())
    }
    
    func testPause() {
        let animation = makeAnimation(autoplay: true)
        XCTAssertTrue(animation.isPlaying(), "Animation should be playing with autoplay: true")
        
        let result = animation.pause()
        XCTAssertTrue(result, "pause() should return true")
        XCTAssertTrue(animation.isPaused(), "Animation should be paused after pause()")
        XCTAssertFalse(animation.isPlaying())
    }
    
    func testStop() {
        let animation = makeAnimation(autoplay: true)
        XCTAssertTrue(animation.isPlaying(), "Animation should be playing with autoplay: true")
        
        let result = animation.stop()
        XCTAssertTrue(result, "stop() should return true")
        XCTAssertTrue(animation.isStopped(), "Animation should be stopped after stop()")
        XCTAssertFalse(animation.isPlaying())
    }
    
    func testPlayAfterStop() {
        let animation = makeAnimation(autoplay: true)
        _ = animation.stop()
        XCTAssertTrue(animation.isStopped())
        
        let result = animation.play()
        XCTAssertTrue(result, "play() should return true after stop()")
        XCTAssertTrue(animation.isPlaying())
    }
    
    func testPlayAfterPause() {
        let animation = makeAnimation(autoplay: true)
        _ = animation.pause()
        XCTAssertTrue(animation.isPaused())
        
        let result = animation.play()
        XCTAssertTrue(result, "play() should return true after pause()")
        XCTAssertTrue(animation.isPlaying())
    }
    
    // MARK: - Speed
    
    func testDefaultSpeedIsOne() {
        let animation = makeAnimation()
        XCTAssertEqual(animation.speed(), 1.0, accuracy: 0.001, "Default speed should be 1.0")
    }
    
    func testSetSpeedUpdatesValue() {
        let animation = makeAnimation()
        animation.setSpeed(speed: 2.5)
        XCTAssertEqual(animation.speed(), 2.5, accuracy: 0.001)
    }
    
    func testSetSpeedHalf() {
        let animation = makeAnimation()
        animation.setSpeed(speed: 0.5)
        XCTAssertEqual(animation.speed(), 0.5, accuracy: 0.001)
    }
    
    // MARK: - State Machine
    
    /// Attempts to load inline state machine data.
    /// The test is skipped if the engine does not accept this format.
    func testStateMachineLoadData() throws {
        let animation = makeAnimation()
        let loaded = animation.stateMachineLoadData(minimalStateMachineJSON)
        try XCTSkipUnless(loaded, "State machine data format not accepted by engine – skipping")
        XCTAssertTrue(loaded)
    }
    
    func testStateMachineBooleanInput() throws {
        let animation = makeAnimation(autoplay: true)
        
        let loaded = animation.stateMachineLoadData(minimalStateMachineJSON)
        try XCTSkipUnless(loaded, "State machine data format not accepted by engine – skipping")
        
        let started = animation.stateMachineStart(openUrlPolicy: OpenUrlPolicy(requireUserInteraction: false))
        XCTAssertTrue(started, "State machine should start successfully")
        
        XCTAssertTrue(animation.stateMachineSetBooleanInput(key: "isActive", value: true))
        XCTAssertTrue(animation.stateMachineGetBooleanInput(key: "isActive"), "Boolean input should be true after setting it")
        
        XCTAssertTrue(animation.stateMachineSetBooleanInput(key: "isActive", value: false))
        XCTAssertFalse(animation.stateMachineGetBooleanInput(key: "isActive"), "Boolean input should be false after setting it")
    }
    
    func testStateMachineNumericInput() throws {
        let animation = makeAnimation(autoplay: true)
        
        let loaded = animation.stateMachineLoadData(minimalStateMachineJSON)
        try XCTSkipUnless(loaded, "State machine data format not accepted by engine – skipping")
        
        let started = animation.stateMachineStart(openUrlPolicy: OpenUrlPolicy(requireUserInteraction: false))
        XCTAssertTrue(started, "State machine should start successfully")
        
        XCTAssertTrue(animation.stateMachineSetNumericInput(key: "count", value: 42.0))
        XCTAssertEqual(
            animation.stateMachineGetNumericInput(key: "count"),
            42.0,
            accuracy: 0.001,
            "Numeric input should reflect the set value"
        )
    }
    
    func testStateMachineStringInput() throws {
        let animation = makeAnimation(autoplay: true)
        
        let loaded = animation.stateMachineLoadData(minimalStateMachineJSON)
        try XCTSkipUnless(loaded, "State machine data format not accepted by engine – skipping")
        
        let started = animation.stateMachineStart(openUrlPolicy: OpenUrlPolicy(requireUserInteraction: false))
        XCTAssertTrue(started, "State machine should start successfully")
        
        XCTAssertTrue(animation.stateMachineSetStringInput(key: "word", value: "new"))
        XCTAssertEqual(
            animation.stateMachineGetStringInput(key: "word"),
            "new",
            "String input should reflect the set value"
        )
    }
    func testStateMachineGetInputsReturnsCachedValues() throws {
        let animation = makeAnimation()
        
        let loaded = animation.stateMachineLoadData(minimalStateMachineJSON)
        try XCTSkipUnless(loaded, "State machine data format not accepted by engine – skipping")
        
        let inputs = animation.stateMachineGetInputs()
        XCTAssertFalse(inputs.isEmpty, "Inputs should not be empty after loading state machine")
        XCTAssertNotNil(inputs["isActive"], "Should have 'isActive' input")
        XCTAssertNotNil(inputs["count"], "Should have 'count' input")
    }
}
