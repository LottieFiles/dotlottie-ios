//
//  DotLottiePlayerBridge.swift
//  DotLottie
//
//  Swift bridge for C API (dotlottie_player.h)
//

import Foundation
import DotLottiePlayer

// MARK: - Mode

public enum Mode: UInt32 {
    case forward = 0
    case reverse = 1
    case bounce = 2
    case reverseBounce = 3

    internal var cMode: dotlottieMode {
        switch self {
        case .forward: return Forward
        case .reverse: return Reverse
        case .bounce: return Bounce
        case .reverseBounce: return ReverseBounce
        }
    }

    internal init(cMode: dotlottieMode) {
        switch cMode {
        case Forward: self = .forward
        case Reverse: self = .reverse
        case Bounce: self = .bounce
        case ReverseBounce: self = .reverseBounce
        default: self = .forward
        }
    }
}

// MARK: - Fit

public enum Fit: UInt32 {
    case contain = 0
    case fill = 1
    case cover = 2
    case fitWidth = 3
    case fitHeight = 4
    case none = 5

    internal var cFit: dotlottieFit {
        switch self {
        case .contain: return Contain
        case .fill: return Fill
        case .cover: return Cover
        case .fitWidth: return FitWidth
        case .fitHeight: return FitHeight
        case .none: return dotlottieFit(rawValue: 5)
        }
    }

    internal init(cFit: dotlottieFit) {
        switch cFit.rawValue {
        case 0: self = .contain
        case 1: self = .fill
        case 2: self = .cover
        case 3: self = .fitWidth
        case 4: self = .fitHeight
        case 5: self = .none
        default: self = .contain
        }
    }
}

// MARK: - ColorSpace

public enum ColorSpace: UInt32 {
    case abgr8888 = 0
    case abgr8888s = 1
    case argb8888 = 2
    case argb8888s = 3

    internal var cColorSpace: dotlottieColorSpace {
        switch self {
        case .abgr8888: return ABGR8888
        case .abgr8888s: return ABGR8888S
        case .argb8888: return ARGB8888
        case .argb8888s: return ARGB8888S
        }
    }
}

// MARK: - PlaybackStatus

public enum PlaybackStatus: UInt32 {
    case playing = 0
    case paused = 1
    case stopped = 2

    internal init(cStatus: dotlottiePlaybackStatus) {
        switch cStatus {
        case Playing: self = .playing
        case Paused: self = .paused
        case Stopped: self = .stopped
        default: self = .stopped
        }
    }
}

// MARK: - Layout

public struct Layout {
    public var fit: Fit
    public var alignX: Float
    public var alignY: Float

    public init(fit: Fit = .contain, alignX: Float = 0.5, alignY: Float = 0.5) {
        self.fit = fit
        self.alignX = alignX
        self.alignY = alignY
    }

    internal var cLayout: dotlottieLayout {
        var layout = dotlottieLayout()
        layout.fit = fit.cFit
        layout.align = (alignX, alignY)
        return layout
    }

    internal init(cLayout: dotlottieLayout) {
        self.fit = Fit(cFit: cLayout.fit)
        self.alignX = cLayout.align.0
        self.alignY = cLayout.align.1
    }
}

// MARK: - Config

public struct Config {
    public var mode: Mode
    public var loopAnimation: Bool
    public var loopCount: UInt32
    public var speed: Float
    public var useFrameInterpolation: Bool
    public var autoplay: Bool
    public var segment: [Float]
    public var backgroundColor: UInt32
    public var layout: Layout
    public var marker: String
    public var themeId: String
    public var stateMachineId: String
    public var animationId: String

    public init(
        autoplay: Bool = false,
        loopAnimation: Bool = false,
        loopCount: UInt32 = 0,
        mode: Mode = .forward,
        speed: Float = 1.0,
        useFrameInterpolation: Bool = false,
        segment: [Float] = [],
        backgroundColor: UInt32 = 0,
        layout: Layout = Layout(),
        marker: String = "",
        themeId: String = "",
        stateMachineId: String = "",
        animationId: String = ""
    ) {
        self.autoplay = autoplay
        self.loopAnimation = loopAnimation
        self.loopCount = loopCount
        self.mode = mode
        self.speed = speed
        self.useFrameInterpolation = useFrameInterpolation
        self.segment = segment
        self.backgroundColor = backgroundColor
        self.layout = layout
        self.marker = marker
        self.themeId = themeId
        self.stateMachineId = stateMachineId
        self.animationId = animationId
    }
}

// MARK: - Manifest

public struct Manifest {
    public var generator: String?
    public var version: String?
    public var animations: [ManifestAnimation]
    public var themes: [ManifestTheme]?
    public var stateMachines: [ManifestStateMachine]?
    public var initial: ManifestInitial?

    public init(
        generator: String? = nil,
        version: String? = nil,
        animations: [ManifestAnimation],
        themes: [ManifestTheme]? = nil,
        stateMachines: [ManifestStateMachine]? = nil,
        initial: ManifestInitial? = nil
    ) {
        self.generator = generator
        self.version = version
        self.animations = animations
        self.themes = themes
        self.stateMachines = stateMachines
        self.initial = initial
    }
}

public struct ManifestInitial {
    public var stateMachine: String?
    public var animation: String?

    public init(stateMachine: String? = nil, animation: String? = nil) {
        self.stateMachine = stateMachine
        self.animation = animation
    }
}

public struct ManifestAnimation {
    public var id: String
    public var name: String?
    public var initialTheme: String?
    public var background: String?
    public var themes: [String]?

    public init(id: String, name: String? = nil, initialTheme: String? = nil, background: String? = nil, themes: [String]? = nil) {
        self.id = id
        self.name = name
        self.initialTheme = initialTheme
        self.background = background
        self.themes = themes
    }
}

public struct ManifestTheme {
    public var id: String
    public var name: String?

    public init(id: String, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

public struct ManifestStateMachine {
    public var id: String
    public var name: String?

    public init(id: String, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

// MARK: - Marker

public struct Marker {
    public var name: String
    public var time: Float
    public var duration: Float

    public init(name: String, time: Float, duration: Float) {
        self.name = name
        self.time = time
        self.duration = duration
    }
}

// MARK: - OpenUrlPolicy

public struct OpenUrlPolicy: Equatable, Hashable {
    public var requireUserInteraction: Bool
    public var whitelist: [String]

    public init(requireUserInteraction: Bool = true, whitelist: [String] = []) {
        self.requireUserInteraction = requireUserInteraction
        self.whitelist = whitelist
    }
}

// MARK: - Events

public enum Event {
    case pointerDown(x: Float, y: Float)
    case pointerUp(x: Float, y: Float)
    case pointerMove(x: Float, y: Float)
    case pointerEnter(x: Float, y: Float)
    case pointerExit(x: Float, y: Float)
    case click(x: Float, y: Float)
    case onComplete
    case onLoopComplete

    internal func toCEvent() -> dotlottiePlayerEvent {
        var event = dotlottiePlayerEvent()

        switch self {
        case .pointerDown(let x, let y):
            event.tag = PointerDown
            event.pointer_down = dotlottiePointerDown_Body(x: x, y: y)
        case .pointerUp(let x, let y):
            event.tag = PointerUp
            event.pointer_up = dotlottiePointerUp_Body(x: x, y: y)
        case .pointerMove(let x, let y):
            event.tag = PointerMove
            event.pointer_move = dotlottiePointerMove_Body(x: x, y: y)
        case .pointerEnter(let x, let y):
            event.tag = PointerEnter
            event.pointer_enter = dotlottiePointerEnter_Body(x: x, y: y)
        case .pointerExit(let x, let y):
            event.tag = PointerExit
            event.pointer_exit = dotlottiePointerExit_Body(x: x, y: y)
        case .click(let x, let y):
            event.tag = Click
            event.click = dotlottieClick_Body(x: x, y: y)
        case .onComplete:
            event.tag = OnComplete
        case .onLoopComplete:
            event.tag = OnLoopComplete
        }

        return event
    }
}

// MARK: - Observer Protocols

public protocol Observer: AnyObject {
    func onLoad()
    func onLoadError()
    func onPlay()
    func onPause()
    func onStop()
    func onFrame(frameNo: Float)
    func onRender(frameNo: Float)
    func onLoop(loopCount: UInt32)
    func onComplete()
}

public protocol StateMachineObserver: AnyObject {
    func onTransition(previousState: String, newState: String)
    func onStateEntered(enteringState: String)
    func onStateExit(leavingState: String)
}

public protocol StateMachineInternalObserver: AnyObject {
    func onMessage(message: String)
}

// MARK: - String Buffer Helper

/// Two-call buffer API pattern: first call with nil to get required size, second to fill.
private func stringFromBufferAPI(
    _ body: (_ buffer: UnsafeMutablePointer<CChar>?, _ sizeOut: UnsafeMutablePointer<UInt>?) -> dotlottieDotLottieResult
) -> String? {
    var size: UInt = 0
    guard body(nil, &size) == Success, size > 0 else { return nil }
    var buffer = [CChar](repeating: 0, count: Int(size))
    guard body(&buffer, nil) == Success else { return nil }
    return String(cString: buffer)
}

// MARK: - DotLottiePlayer

public class DotLottiePlayer {
    private var playerPtr: OpaquePointer?
    private var stateMachinePtr: OpaquePointer?
    public private(set) var isStateMachineRunning: Bool = false

    private var observers: [Observer] = []
    private var stateMachineObservers: [StateMachineObserver] = []
    private var stateMachineInternalObservers: [StateMachineInternalObserver] = []

    private var eventPollTimer: Timer?

    public init(config: Config, threads: UInt32 = 0) {
        playerPtr = dotlottie_new_player(threads)
        applyConfig(config)
        startEventPolling()
    }

    public static func withThreads(config: Config, threads: UInt32) -> DotLottiePlayer {
        return DotLottiePlayer(config: config, threads: threads)
    }

    private func applyConfig(_ config: Config) {
        guard let ptr = playerPtr else { return }
        dotlottie_set_mode(ptr, config.mode.cMode)
        dotlottie_set_loop(ptr, config.loopAnimation)
        dotlottie_set_loop_count(ptr, config.loopCount)
        dotlottie_set_speed(ptr, config.speed)
        dotlottie_set_use_frame_interpolation(ptr, config.useFrameInterpolation)
        dotlottie_set_autoplay(ptr, config.autoplay)
        let bgR = UInt8((config.backgroundColor >> 16) & 0xFF)
        let bgG = UInt8((config.backgroundColor >> 8) & 0xFF)
        let bgB = UInt8(config.backgroundColor & 0xFF)
        let bgA = UInt8((config.backgroundColor >> 24) & 0xFF)
        dotlottie_set_background(ptr, bgR, bgG, bgB, bgA)
        let cLayout = config.layout.cLayout
        dotlottie_set_layout(ptr, cLayout)

        if config.segment.count >= 2 {
            var seg: (Float, Float) = (config.segment[0], config.segment[1])
            _ = withUnsafePointer(to: &seg) { dotlottie_set_segment(ptr, $0) }
        }

        if !config.marker.isEmpty {
            _ = config.marker.withCString { dotlottie_set_marker(ptr, $0) }
        }

        if !config.themeId.isEmpty {
            _ = config.themeId.withCString { dotlottie_set_theme(ptr, $0) }
        }
    }

    deinit {
        stopEventPolling()

        if let smPtr = stateMachinePtr {
            dotlottie_state_machine_release(smPtr)
            stateMachinePtr = nil
        }

        if let ptr = playerPtr {
            dotlottie_destroy(ptr)
            playerPtr = nil
        }
    }

    // MARK: - Font Loading (Global)

    public static func loadFont(name: String, data: Data) -> Bool {
        return name.withCString { namePtr in
            data.withUnsafeBytes { bufferPtr in
                guard let base = bufferPtr.baseAddress else { return false }
                return dotlottie_load_font(namePtr, base.assumingMemoryBound(to: UInt8.self), UInt(data.count)) == Success
            }
        }
    }

    public static func unloadFont(name: String) -> Bool {
        return name.withCString { dotlottie_unload_font($0) == Success }
    }

    // MARK: - Loading

    public func loadAnimationData(animationData: String) -> Bool {
        guard let ptr = playerPtr else { return false }
        return animationData.withCString { dotlottie_load_animation_data(ptr, $0) == Success }
    }

    public func loadAnimationPath(animationPath: String) -> Bool {
        guard let ptr = playerPtr else { return false }
        return animationPath.withCString { dotlottie_load_animation_path(ptr, $0) == Success }
    }

    public func loadAnimation(animationId: String) -> Bool {
        guard let ptr = playerPtr else { return false }
        return animationId.withCString { dotlottie_load_animation(ptr, $0) == Success }
    }

    public func loadDotlottieData(fileData: Data) -> Bool {
        guard let ptr = playerPtr else { return false }
        return fileData.withUnsafeBytes { (bufferPtr: UnsafeRawBufferPointer) in
            guard let base = bufferPtr.baseAddress else { return false }
            return dotlottie_load_dotlottie_data(ptr, base.assumingMemoryBound(to: CChar.self), UInt(bufferPtr.count)) == Success
        }
    }

    // MARK: - Playback

    public func play() -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_play(ptr) == Success
    }

    public func pause() -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_pause(ptr) == Success
    }

    public func stop() -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_stop(ptr) == Success
    }

    public func tick(dt: Float) -> Bool {
        var rendered: Bool = false
        if isStateMachineRunning, let smPtr = stateMachinePtr {
            dotlottie_state_machine_tick(smPtr, dt, &rendered)
        } else if let ptr = playerPtr {
            dotlottie_tick(ptr, dt, &rendered)
        }
        return rendered
    }

    public func render() -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_render(ptr) == Success
    }

    public func setFrame(no: Float) -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_frame(ptr, no) == Success
    }

    public func animationSize() -> CGSize {
        guard let ptr = playerPtr else { return CGSize(width: 0, height: 0) }
        var w: Float = 0
        var h: Float = 0
        dotlottie_get_animation_size(ptr, &w, &h)
        return CGSize(width: Double(w), height: Double(h))
    }

    // MARK: - State

    public func isLoaded() -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_is_loaded(ptr)
    }

    public func isComplete() -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_is_complete(ptr)
    }

    public func playbackStatus() -> PlaybackStatus {
        guard let ptr = playerPtr else { return .stopped }
        return PlaybackStatus(cStatus: dotlottie_get_playback_status(ptr))
    }

    public func isPlaying() -> Bool { playbackStatus() == .playing }
    public func isPaused() -> Bool { playbackStatus() == .paused }
    public func isStopped() -> Bool { playbackStatus() == .stopped }

    // MARK: - Properties

    public func totalFrames() -> Float {
        guard let ptr = playerPtr else { return 0 }
        var result: Float = 0
        dotlottie_get_total_frames(ptr, &result)
        return result
    }

    public func currentFrame() -> Float {
        guard let ptr = playerPtr else { return 0 }
        var result: Float = 0
        dotlottie_get_current_frame(ptr, &result)
        return result
    }

    public func duration() -> Float {
        guard let ptr = playerPtr else { return 0 }
        var result: Float = 0
        dotlottie_get_duration(ptr, &result)
        return result
    }

    /// Current loop iteration count during playback.
    public func currentLoopCount() -> UInt32 {
        guard let ptr = playerPtr else { return 0 }
        var result: UInt32 = 0
        dotlottie_get_current_loop_count(ptr, &result)
        return result
    }

    // MARK: - Configuration Getters

    public func getMode() -> Mode {
        guard let ptr = playerPtr else { return .forward }
        return Mode(cMode: dotlottie_get_mode(ptr))
    }

    public func getSpeed() -> Float {
        guard let ptr = playerPtr else { return 1.0 }
        return dotlottie_get_speed(ptr)
    }

    public func getLoop() -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_get_loop(ptr)
    }

    /// Configured max loop count (0 = infinite).
    public func getLoopCount() -> UInt32 {
        guard let ptr = playerPtr else { return 0 }
        return dotlottie_get_loop_count(ptr)
    }

    public func getAutoplay() -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_get_autoplay(ptr)
    }

    public func getUseFrameInterpolation() -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_get_use_frame_interpolation(ptr)
    }

    public func getBackgroundColor() -> UInt32 {
        guard let ptr = playerPtr else { return 0 }
        var r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0, a: UInt8 = 0
        dotlottie_get_background(ptr, &r, &g, &b, &a)
        return (UInt32(a) << 24) | (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
    }

    public func getSegment() -> [Float]? {
        guard let ptr = playerPtr else { return nil }
        var seg: (Float, Float) = (0, 0)
        let result = withUnsafeMutablePointer(to: &seg) { dotlottie_get_segment(ptr, $0) }
        guard result == Success else { return nil }
        return [seg.0, seg.1]
    }

    public func getLayout() -> Layout {
        guard let ptr = playerPtr else { return Layout() }
        var cLayout = dotlottieLayout()
        dotlottie_get_layout(ptr, &cLayout)
        return Layout(cLayout: cLayout)
    }

    public func getActiveMarker() -> String? {
        guard let ptr = playerPtr else { return nil }
        return stringFromBufferAPI { dotlottie_get_active_marker(ptr, $0, $1) }
    }

    // MARK: - Configuration Setters

    @discardableResult
    public func setMode(_ mode: Mode) -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_mode(ptr, mode.cMode) == Success
    }

    @discardableResult
    public func setSpeed(_ speed: Float) -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_speed(ptr, speed) == Success
    }

    @discardableResult
    public func setLoop(_ loop: Bool) -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_loop(ptr, loop) == Success
    }

    @discardableResult
    public func setLoopCount(_ count: UInt32) -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_loop_count(ptr, count) == Success
    }

    @discardableResult
    public func setAutoplay(_ autoplay: Bool) -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_autoplay(ptr, autoplay) == Success
    }

    @discardableResult
    public func setUseFrameInterpolation(_ enabled: Bool) -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_use_frame_interpolation(ptr, enabled) == Success
    }

    @discardableResult
    public func setBackgroundColor(_ color: UInt32) -> Bool {
        guard let ptr = playerPtr else { return false }
        let r = UInt8((color >> 16) & 0xFF)
        let g = UInt8((color >> 8) & 0xFF)
        let b = UInt8(color & 0xFF)
        let a = UInt8((color >> 24) & 0xFF)
        return dotlottie_set_background(ptr, r, g, b, a) == Success
    }

    @discardableResult
    public func setSegment(start: Float, end: Float) -> Bool {
        guard let ptr = playerPtr else { return false }
        var seg: (Float, Float) = (start, end)
        return withUnsafePointer(to: &seg) { dotlottie_set_segment(ptr, $0) == Success }
    }

    @discardableResult
    public func clearSegment() -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_segment(ptr, nil) == Success
    }

    @discardableResult
    public func setMarker(_ marker: String?) -> Bool {
        guard let ptr = playerPtr else { return false }
        if let marker = marker, !marker.isEmpty {
            return marker.withCString { dotlottie_set_marker(ptr, $0) == Success }
        }
        return dotlottie_set_marker(ptr, nil) == Success
    }

    @discardableResult
    public func setLayout(_ layout: Layout) -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_layout(ptr, layout.cLayout) == Success
    }

    @discardableResult
    public func setViewport(x: Int32, y: Int32, width: Int32, height: Int32) -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_viewport(ptr, x, y, width, height) == Success
    }

    public func setConfig(config: Config) {
        applyConfig(config)
    }

    // MARK: - Renderer Targets

    public func setSoftwareTarget(
        buffer: UnsafeMutablePointer<UInt32>,
        width: UInt32,
        height: UInt32,
        colorSpace: ColorSpace = .argb8888
    ) -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_sw_target(ptr, buffer, width, height, colorSpace.cColorSpace) == Success
    }

    public func setGLTarget(
        display: UnsafeMutableRawPointer?,
        surface: UnsafeMutableRawPointer?,
        context: UnsafeMutableRawPointer?,
        id: Int32,
        width: UInt32,
        height: UInt32
    ) -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_gl_target(ptr, display, surface, context, id, width, height) == Success
    }

    public func setWebGPUTarget(
        device: UnsafeMutableRawPointer?,
        instance: UnsafeMutableRawPointer?,
        target: UnsafeMutableRawPointer?,
        width: UInt32,
        height: UInt32,
        targetType: dotlottieDotLottieWgpuTargetType = Surface
    ) -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_set_wg_target(ptr, device, instance, target, width, height, targetType) == Success
    }


    // MARK: - Manifest

    /// Returns the manifest parsed from JSON, or nil if no manifest is available.
    public func manifest() -> Manifest? {
        guard let ptr = playerPtr else { return nil }
        guard let jsonString = stringFromBufferAPI({ dotlottie_get_manifest(ptr, $0, $1) }) else { return nil }
        return parseManifestJSON(jsonString)
    }

    private func parseManifestJSON(_ json: String) -> Manifest? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let generator = obj["generator"] as? String
        let version = obj["version"] as? String
        
        var initial: ManifestInitial? = nil
        if let initialObj = obj["initial"] as? [String: Any] {
            initial = ManifestInitial(
                stateMachine: initialObj["stateMachine"] as? String,
                animation: initialObj["animation"] as? String
            )
        }

        var animations: [ManifestAnimation] = []
        if let anims = obj["animations"] as? [[String: Any]] {
            animations = anims.compactMap { anim in
                guard let id = anim["id"] as? String else { return nil }
                return ManifestAnimation(
                    id: id,
                    name: anim["name"] as? String,
                    initialTheme: anim["initialTheme"] as? String,
                    background: anim["background"] as? String,
                    themes: anim["themes"] as? [String]
                )
            }
        }

        var themes: [ManifestTheme] = []
        if let themeArr = obj["themes"] as? [[String: Any]] {
            themes = themeArr.compactMap { t in
                guard let id = t["id"] as? String else { return nil }
                return ManifestTheme(id: id, name: t["name"] as? String)
            }
        }

        var stateMachines: [ManifestStateMachine] = []
        if let smArr = obj["stateMachines"] as? [[String: Any]] {
            stateMachines = smArr.compactMap { sm in
                guard let id = sm["id"] as? String else { return nil }
                return ManifestStateMachine(id: id, name: sm["name"] as? String)
            }
        }

        return Manifest(
            generator: generator,
            version: version,
            animations: animations.isEmpty ? [] : animations,
            themes: themes.isEmpty ? nil : themes,
            stateMachines: stateMachines.isEmpty ? nil : stateMachines,
            initial: initial
        )
    }

    // MARK: - Markers

    public func markers() -> [Marker] {
        guard let ptr = playerPtr else { return [] }
        var count: UInt32 = 0
        guard dotlottie_get_markers_count(ptr, &count) == Success, count > 0 else { return [] }

        var result: [Marker] = []
        for i in 0..<count {
            var namePtr: UnsafePointer<CChar>? = nil
            var time: Float = 0
            var duration: Float = 0
            if dotlottie_get_marker(ptr, i, &namePtr, &time, &duration) == Success, let namePtr = namePtr {
                result.append(Marker(name: String(cString: namePtr), time: time, duration: duration))
            }
        }
        return result
    }

    // MARK: - Theme

    @discardableResult
    public func setTheme(themeId: String) -> Bool {
        guard let ptr = playerPtr else { return false }
        return themeId.withCString { dotlottie_set_theme(ptr, $0) == Success }
    }

    @discardableResult
    public func resetTheme() -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_reset_theme(ptr) == Success
    }

    @discardableResult
    public func setThemeData(themeData: String) -> Bool {
        guard let ptr = playerPtr else { return false }
        return themeData.withCString { dotlottie_set_theme_data(ptr, $0) == Success }
    }

    public func activeThemeId() -> String {
        guard let ptr = playerPtr else { return "" }
        return stringFromBufferAPI({ dotlottie_get_theme_id(ptr, $0, $1) }) ?? ""
    }

    public func activeAnimationId() -> String {
        guard let ptr = playerPtr else { return "" }
        return stringFromBufferAPI({ dotlottie_get_animation_id(ptr, $0, $1) }) ?? ""
    }

    // MARK: - Slots

    @discardableResult
    public func setSlotsStr(slots: String) -> Bool {
        guard let ptr = playerPtr else { return false }
        return slots.withCString { dotlottie_set_slots_str(ptr, $0) == Success }
    }

    @discardableResult
    public func clearSlots() -> Bool {
        guard let ptr = playerPtr else { return false }
        return dotlottie_clear_slots(ptr) == Success
    }

    @discardableResult
    public func clearSlot(slotId: String) -> Bool {
        guard let ptr = playerPtr else { return false }
        return slotId.withCString { dotlottie_clear_slot(ptr, $0) == Success }
    }

    @discardableResult
    public func setColorSlot(slotId: String, r: Float, g: Float, b: Float) -> Bool {
        guard let ptr = playerPtr else { return false }
        return slotId.withCString { dotlottie_set_color_slot(ptr, $0, r, g, b) == Success }
    }

    @discardableResult
    public func setScalarSlot(slotId: String, value: Float) -> Bool {
        guard let ptr = playerPtr else { return false }
        return slotId.withCString { dotlottie_set_scalar_slot(ptr, $0, value) == Success }
    }

    @discardableResult
    public func setTextSlot(slotId: String, text: String) -> Bool {
        guard let ptr = playerPtr else { return false }

        // Merge the new text value over the existing text document
        // so properties like font, size and colour are preserved, only
        // overriding the text content ("t").
        var mergedTextDoc: [String: Any] = ["t": text]

        if let existingStr = slotId.withCString({ idPtr in
                stringFromBufferAPI { dotlottie_get_slot_str(ptr, idPtr, $0, $1) }
            }),
           let existingData = existingStr.data(using: .utf8),
           let existingValue = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any],
           let keyframes = existingValue["k"] as? [[String: Any]],
           let firstSlot = keyframes.first?["s"] as? [String: Any] {
            mergedTextDoc = firstSlot.merging(["t": text]) { _, new in new }
        }

        let slot: [String: Any] = [
            "a": 0,
            "k": [["t": 0, "s": mergedTextDoc]],
        ]

        guard let slotData = try? JSONSerialization.data(withJSONObject: slot),
              let slotJson = String(data: slotData, encoding: .utf8) else {
            return false
        }

        return slotId.withCString { idPtr in
            slotJson.withCString { dotlottie_set_slot_str(ptr, idPtr, $0) == Success }
        }
    }

    @discardableResult
    public func setVectorSlot(slotId: String, x: Float, y: Float) -> Bool {
        guard let ptr = playerPtr else { return false }
        return slotId.withCString { dotlottie_set_vector_slot(ptr, $0, x, y) == Success }
    }

    @discardableResult
    public func setPositionSlot(slotId: String, x: Float, y: Float) -> Bool {
        guard let ptr = playerPtr else { return false }
        return slotId.withCString { dotlottie_set_position_slot(ptr, $0, x, y) == Success }
    }

    @discardableResult
    public func setImageSlotPath(slotId: String, path: String) -> Bool {
        guard let ptr = playerPtr else { return false }
        return slotId.withCString { idPtr in
            path.withCString { dotlottie_set_image_slot_path(ptr, idPtr, $0) == Success }
        }
    }

    @discardableResult
    public func setImageSlotDataUrl(slotId: String, dataUrl: String) -> Bool {
        guard let ptr = playerPtr else { return false }
        return slotId.withCString { idPtr in
            dataUrl.withCString { dotlottie_set_image_slot_data_url(ptr, idPtr, $0) == Success }
        }
    }

    // MARK: - State Machine

    public func stateMachineLoad(stateMachineId: String) -> Bool {
        guard let ptr = playerPtr else { return false }
        if let smPtr = stateMachinePtr {
            dotlottie_state_machine_release(smPtr)
            stateMachinePtr = nil
        }
        stateMachinePtr = stateMachineId.withCString { dotlottie_state_machine_load(ptr, $0) }
        return stateMachinePtr != nil
    }

    public func stateMachineLoadData(stateMachine: String) -> Bool {
        guard let ptr = playerPtr else { return false }
        if let smPtr = stateMachinePtr {
            dotlottie_state_machine_release(smPtr)
            stateMachinePtr = nil
        }
        var mutableBytes = [CChar](stateMachine.utf8CString)
        stateMachinePtr = mutableBytes.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress.flatMap { dotlottie_state_machine_load_data(ptr, $0) }
        }
        return stateMachinePtr != nil
    }

    public func stateMachineStart(openUrlPolicy: OpenUrlPolicy = OpenUrlPolicy()) -> Bool {
        guard let smPtr = stateMachinePtr else { return false }
        let whitelistStr = openUrlPolicy.whitelist.joined(separator: ",")
        let result: Bool
        if whitelistStr.isEmpty {
            result = dotlottie_state_machine_start(smPtr, nil, openUrlPolicy.requireUserInteraction) == Success
        } else {
            result = whitelistStr.withCString { dotlottie_state_machine_start(smPtr, $0, openUrlPolicy.requireUserInteraction) == Success }
        }
        if result { isStateMachineRunning = true }
        return result
    }

    @discardableResult
    public func stateMachineStop() -> Bool {
        isStateMachineRunning = false
        guard let smPtr = stateMachinePtr else { return false }
        return dotlottie_state_machine_stop(smPtr) == Success
    }

    public func stateMachinePostEvent(event: Event) {
        guard let smPtr = stateMachinePtr else { return }
        var cEvent = event.toCEvent()
        _ = withUnsafePointer(to: &cEvent) { dotlottie_state_machine_post_event(smPtr, $0) }
    }

    @discardableResult
    public func stateMachinePostClick(x: Float, y: Float) -> Bool {
        guard let smPtr = stateMachinePtr else { return false }
        return dotlottie_state_machine_post_click(smPtr, x, y) == Success
    }

    @discardableResult
    public func stateMachinePostPointerDown(x: Float, y: Float) -> Bool {
        guard let smPtr = stateMachinePtr else { return false }
        return dotlottie_state_machine_post_pointer_down(smPtr, x, y) == Success
    }

    @discardableResult
    public func stateMachinePostPointerUp(x: Float, y: Float) -> Bool {
        guard let smPtr = stateMachinePtr else { return false }
        return dotlottie_state_machine_post_pointer_up(smPtr, x, y) == Success
    }

    @discardableResult
    public func stateMachinePostPointerMove(x: Float, y: Float) -> Bool {
        guard let smPtr = stateMachinePtr else { return false }
        return dotlottie_state_machine_post_pointer_move(smPtr, x, y) == Success
    }

    @discardableResult
    public func stateMachinePostPointerEnter(x: Float, y: Float) -> Bool {
        guard let smPtr = stateMachinePtr else { return false }
        return dotlottie_state_machine_post_pointer_enter(smPtr, x, y) == Success
    }

    @discardableResult
    public func stateMachinePostPointerExit(x: Float, y: Float) -> Bool {
        guard let smPtr = stateMachinePtr else { return false }
        return dotlottie_state_machine_post_pointer_exit(smPtr, x, y) == Success
    }

    @discardableResult
    public func stateMachineFireEvent(event: String) -> Bool {
        guard let smPtr = stateMachinePtr else { return false }
        return event.withCString { dotlottie_state_machine_fire_event(smPtr, $0) == Success }
    }

    @discardableResult
    public func stateMachineSetNumericInput(key: String, value: Float) -> Bool {
        guard let smPtr = stateMachinePtr else { return false }
        return key.withCString { dotlottie_state_machine_set_numeric_input(smPtr, $0, value) == Success }
    }

    @discardableResult
    public func stateMachineSetStringInput(key: String, value: String) -> Bool {
        guard let smPtr = stateMachinePtr else { return false }
        return key.withCString { keyPtr in
            value.withCString { dotlottie_state_machine_set_string_input(smPtr, keyPtr, $0) == Success }
        }
    }

    @discardableResult
    public func stateMachineSetBooleanInput(key: String, value: Bool) -> Bool {
        guard let smPtr = stateMachinePtr else { return false }
        return key.withCString { dotlottie_state_machine_set_boolean_input(smPtr, $0, value) == Success }
    }

    public func stateMachineGetNumericInput(key: String) -> Float {
        guard let smPtr = stateMachinePtr else { return 0 }
        var result: Float = 0
        _ = key.withCString { dotlottie_state_machine_get_numeric_input(smPtr, $0, &result) }
        return result
    }

    public func stateMachineGetStringInput(key: String) -> String {
        guard let smPtr = stateMachinePtr else { return "" }
        return key.withCString { keyPtr in
            stringFromBufferAPI({ dotlottie_state_machine_get_string_input(smPtr, keyPtr, $0, $1) }) ?? ""
        }
    }

    public func stateMachineGetBooleanInput(key: String) -> Bool {
        guard let smPtr = stateMachinePtr else { return false }
        var result: Bool = false
        _ = key.withCString { dotlottie_state_machine_get_boolean_input(smPtr, $0, &result) }
        return result
    }

    public func stateMachineCurrentState() -> String {
        guard let smPtr = stateMachinePtr else { return "" }
        return stringFromBufferAPI({ dotlottie_state_machine_get_current_state(smPtr, $0, $1) }) ?? ""
    }

    public func stateMachineStatus() -> String {
        guard let smPtr = stateMachinePtr else { return "" }
        return stringFromBufferAPI({ dotlottie_state_machine_get_status(smPtr, $0, $1) }) ?? ""
    }

    /// Returns raw bit flags indicating which interaction types are needed.
    public func stateMachineFrameworkSetup() -> UInt16 {
        guard let smPtr = stateMachinePtr else { return 0 }
        var result: UInt16 = 0
        dotlottie_state_machine_get_framework_setup(smPtr, &result)
        return result
    }

    public func getStateMachine(stateMachineId: String) -> String {
        guard let ptr = playerPtr else { return "" }
        return stateMachineId.withCString { idPtr in
            stringFromBufferAPI({ dotlottie_get_state_machine(ptr, idPtr, $0, $1) }) ?? ""
        }
    }

    // MARK: - Observers

    public func subscribe(observer: Observer) {
        observers.append(observer)
    }

    public func unsubscribe(observer: Observer) {
        observers.removeAll { $0 === observer }
    }

    @discardableResult
    public func stateMachineSubscribe(observer: StateMachineObserver) -> Bool {
        stateMachineObservers.append(observer)
        return true
    }

    @discardableResult
    public func stateMachineUnsubscribe(observer: StateMachineObserver) -> Bool {
        stateMachineObservers.removeAll { $0 === observer }
        return true
    }

    @discardableResult
    public func stateMachineInternalSubscribe(observer: StateMachineInternalObserver) -> Bool {
        stateMachineInternalObservers.append(observer)
        return true
    }

    @discardableResult
    public func stateMachineInternalUnsubscribe(observer: StateMachineInternalObserver) -> Bool {
        stateMachineInternalObservers.removeAll { $0 === observer }
        return true
    }

    // MARK: - Event Polling

    private func startEventPolling() {
        eventPollTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.pollEvents()
        }
    }

    private func stopEventPolling() {
        eventPollTimer?.invalidate()
        eventPollTimer = nil
    }

    private func pollEvents() {
        guard playerPtr != nil else { return }

        if isStateMachineRunning, let smPtr = stateMachinePtr {
            var smEvent = dotlottieStateMachineEvent()
            while dotlottie_state_machine_poll_event(smPtr, &smEvent) == 1 {
                handleStateMachineEvent(smEvent)
            }
            var internalEvent = dotlottieStateMachineInternalEvent()
            while dotlottie_state_machine_poll_internal_event(smPtr, &internalEvent) == 1 {
                handleStateMachineInternalEvent(internalEvent)
            }
        } else if let ptr = playerPtr {
            var event = dotlottieDotLottiePlayerEvent()
            while dotlottie_poll_event(ptr, &event) == 1 {
                handlePlayerEvent(event)
            }
        }
    }

    private func handlePlayerEvent(_ event: dotlottieDotLottiePlayerEvent) {
        for observer in observers {
            switch event.event_type {
            case Load: observer.onLoad()
            case LoadError: observer.onLoadError()
            case Play: observer.onPlay()
            case Pause: observer.onPause()
            case Stop: observer.onStop()
            case Frame: observer.onFrame(frameNo: event.data.frame_no)
            case Render: observer.onRender(frameNo: event.data.frame_no)
            case Loop: observer.onLoop(loopCount: event.data.loop_count)
            case Complete: observer.onComplete()
            default: break
            }
        }
    }

    private func handleStateMachineEvent(_ event: dotlottieStateMachineEvent) {
        for observer in stateMachineObservers {
            switch event.event_type {
            case StateMachineTransition:
                let prev = event.data.transition.previous_state.map { String(cString: $0) } ?? ""
                let next = event.data.transition.new_state.map { String(cString: $0) } ?? ""
                observer.onTransition(previousState: prev, newState: next)
            case StateMachineStateEntered:
                let state = event.data.state.state.map { String(cString: $0) } ?? ""
                observer.onStateEntered(enteringState: state)
            case StateMachineStateExit:
                let state = event.data.state.state.map { String(cString: $0) } ?? ""
                observer.onStateExit(leavingState: state)
            default:
                break
            }
        }
    }

    private func handleStateMachineInternalEvent(_ event: dotlottieStateMachineInternalEvent) {
        let message = event.message.map { String(cString: $0) } ?? ""
        for observer in stateMachineInternalObservers {
            observer.onMessage(message: message)
        }
    }
}

// MARK: - Helper Functions

public func createDefaultLayout() -> Layout {
    return Layout(fit: .contain, alignX: 0.5, alignY: 0.5)
}
