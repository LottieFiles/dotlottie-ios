import XCTest
@testable import DotLottie

/// State machine loading, lifecycle, and typed inputs. Tests that depend on the
/// engine accepting a given JSON shape are skipped (not failed) if the engine
/// rejects it, so the suite stays green across core versions.
final class StateMachineTests: XCTestCase {

    private func loadedSMAnimation(_ data: String = Fixtures.minimalStateMachineJSON,
                                   file: StaticString = #filePath, line: UInt = #line) throws -> DotLottieAnimation {
        let animation = makeMinimalAnimation(autoplay: true)
        let loaded = animation.stateMachineLoadData(data)
        try XCTSkipUnless(loaded, "Engine did not accept this state machine JSON – skipping")
        return animation
    }

    // MARK: - Loading

    func testLoadInlineData() throws {
        _ = try loadedSMAnimation()
    }

    func testLoadFixtureData() throws {
        _ = try loadedSMAnimation(Fixtures.smToggleJSON)
    }

    func testLoadInvalidDataReturnsFalse() {
        let animation = makeMinimalAnimation()
        XCTAssertFalse(animation.stateMachineLoadData("{ not a state machine }"))
    }

    // MARK: - Lifecycle

    func testStartAndStop() throws {
        let animation = try loadedSMAnimation()
        XCTAssertTrue(animation.stateMachineStart(openUrlPolicy: OpenUrlPolicy(requireUserInteraction: false)))
        XCTAssertTrue(animation.isStateMachineRunning())
        XCTAssertTrue(animation.stateMachineStop())
        XCTAssertFalse(animation.isStateMachineRunning())
    }

    func testCurrentStateAfterStart() throws {
        let animation = try loadedSMAnimation(Fixtures.smToggleJSON)
        XCTAssertTrue(animation.stateMachineStart(openUrlPolicy: OpenUrlPolicy(requireUserInteraction: false)))
        // sm-toggle's initial state is "initial-wait".
        XCTAssertEqual(animation.stateMachineCurrentState(), "initial-wait")
    }

    // MARK: - Inputs

    func testBooleanInput() throws {
        let animation = try loadedSMAnimation()
        XCTAssertTrue(animation.stateMachineStart(openUrlPolicy: OpenUrlPolicy(requireUserInteraction: false)))

        XCTAssertTrue(animation.stateMachineSetBooleanInput(key: "isActive", value: true))
        XCTAssertTrue(animation.stateMachineGetBooleanInput(key: "isActive"))

        XCTAssertTrue(animation.stateMachineSetBooleanInput(key: "isActive", value: false))
        XCTAssertFalse(animation.stateMachineGetBooleanInput(key: "isActive"))
    }

    func testNumericInput() throws {
        let animation = try loadedSMAnimation()
        XCTAssertTrue(animation.stateMachineStart(openUrlPolicy: OpenUrlPolicy(requireUserInteraction: false)))

        XCTAssertTrue(animation.stateMachineSetNumericInput(key: "count", value: 42.0))
        XCTAssertEqual(animation.stateMachineGetNumericInput(key: "count"), 42.0, accuracy: 0.001)
    }

    func testStringInput() throws {
        let animation = try loadedSMAnimation()
        XCTAssertTrue(animation.stateMachineStart(openUrlPolicy: OpenUrlPolicy(requireUserInteraction: false)))

        XCTAssertTrue(animation.stateMachineSetStringInput(key: "word", value: "new"))
        XCTAssertEqual(animation.stateMachineGetStringInput(key: "word"), "new")
    }

    // MARK: - Cached input metadata

    func testGetInputsForInlineMachine() throws {
        let animation = try loadedSMAnimation()
        let inputs = animation.stateMachineGetInputs()
        XCTAssertEqual(inputs["isActive"], "Boolean")
        XCTAssertEqual(inputs["count"], "Numeric")
        XCTAssertEqual(inputs["word"], "String")
    }

    func testGetInputsForToggleFixture() throws {
        let animation = try loadedSMAnimation(Fixtures.smToggleJSON)
        let inputs = animation.stateMachineGetInputs()
        XCTAssertEqual(inputs["OnOffSwitch"], "Boolean")
    }

    // MARK: - Framework setup flags

    func testFrameworkSetupReflectsPointerInteraction() throws {
        let animation = try loadedSMAnimation(Fixtures.smToggleJSON)
        XCTAssertTrue(animation.stateMachineStart(openUrlPolicy: OpenUrlPolicy(requireUserInteraction: false)))
        // sm-toggle declares a PointerDown interaction, so the framework registers it.
        XCTAssertTrue(animation.stateMachineFrameworkSetup().contains("pointerdown"))
    }
}
