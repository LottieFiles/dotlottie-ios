#if (os(iOS) && !targetEnvironment(macCatalyst)) || os(macOS)

#if os(iOS)
import UIKit
import QuartzCore
import DotLottiePlayer
public typealias PlatformBase = UIView
#elseif os(macOS)
import AppKit
import QuartzCore
import DotLottiePlayer
public typealias PlatformBase = NSView
#endif

/// A UIView/NSView that renders a Lottie animation via WebGPU (Metal backend).
///
/// Pixels are written directly to a Metal surface — the CPU pixel buffer and
/// CGImage conversion used by the software-rendering path are bypassed entirely.
///
/// Basic usage:
/// ```swift
/// let view = DotLottieWebGPUView(config: Config(autoplay: true, loopAnimation: true))
/// view.loadAnimation(fileName: "my_animation")
/// ```
public class DotLottieWebGPUView: PlatformBase {

    // MARK: - Private state

    private let bridge: DotLottiePlayer

    /// The config the view was created with. Retained so a state machine named in
    /// `config.stateMachineId` can be auto-started after load, mirroring the
    /// software-rendering path (`DotLottieAnimation.loadDotLottie`).
    private let config: Config

    /// The WebGPU context (instance/adapter/device/queue/surface) bound to the layer.
    private var wgpuContext: WgpuContext?

    /// The physical drawable size that was last passed to `setWebGPUTarget`.
    private var configuredSize: CGSize = .zero

    /// Timestamp of the previous tick (seconds), used to compute dt.
    private var lastTickTime: CFTimeInterval = 0

    /// Animation load deferred until the WebGPU canvas exists.
    /// ThorVG requires set_wg_target to be called before loading animation data
    /// so the canvas exists when the animation paint is added.
    private var pendingLoad: (() -> Bool)?

    // MARK: - Platform-specific display link

#if os(iOS)
    private var displayLink: CADisplayLink?
    /// Custom recognizer that feeds touches to the state machine (same one the
    /// software-rendering path uses), so tap-vs-drag and double-tap behaviour match.
    private var gestureManager: GestureManager?
#elseif os(macOS)
    private var displayTimer: DispatchSourceTimer?
    /// Mouse-event router for the state machine (shared with the software path).
    private var gestureManager: GestureManager?
    /// Tracking area for mouseMoved/Entered/Exited (hover → pointerEnter/Exit).
    private var mouseTrackingArea: NSTrackingArea?
#endif

    // MARK: - Metal layer accessor

    private var metalLayer: CAMetalLayer {
#if os(iOS)
        return layer as! CAMetalLayer
#elseif os(macOS)
        return layer as! CAMetalLayer
#endif
    }

    // MARK: - Display scale

    private var displayScale: CGFloat {
#if os(iOS)
        return UIScreen.main.scale
#elseif os(macOS)
        return window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0
#endif
    }

    // MARK: - Init

    public init(config: Config = Config()) {
        self.config = config
        bridge = DotLottiePlayer(config: config)
        super.init(frame: .zero)
        setupMetalLayer()
        setupGestures()
        startDisplayLink()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Layer setup

    /// On iOS the backing layer is overridden to CAMetalLayer via layerClass.
    /// On macOS we assign it explicitly.
#if os(iOS)
    override public class var layerClass: AnyClass { CAMetalLayer.self }

    private func setupMetalLayer() {
        let ml = metalLayer
        ml.pixelFormat = .bgra8Unorm
        ml.framebufferOnly = false
        ml.isOpaque = false
    }
#elseif os(macOS)
    private func setupMetalLayer() {
        wantsLayer = true
        let ml = CAMetalLayer()
        ml.pixelFormat = .bgra8Unorm
        ml.framebufferOnly = false
        ml.isOpaque = false
        // ThorVG's wg renderer always requests WGPUPresentMode_Immediate on Apple targets.
        ml.displaySyncEnabled = false
        layer = ml
    }
#endif

    // MARK: - Layout → WebGPU reconfiguration

#if os(iOS)
    override public func layoutSubviews() {
        super.layoutSubviews()
        reconfigureWebGPUIfNeeded()
    }
#elseif os(macOS)
    override public func layout() {
        super.layout()
        reconfigureWebGPUIfNeeded()
    }
#endif

    // Called on resize
    private func reconfigureWebGPUIfNeeded() {
        let scale = displayScale
        let physical = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        guard physical.width > 0, physical.height > 0 else { return }

        let w = UInt32(physical.width)
        let h = UInt32(physical.height)

        if wgpuContext == nil {
            // First layout: create the wgpu context from the CAMetalLayer.
            // MUST be on the main thread (Metal requirement).
            guard let ctx = WgpuContext(metalLayer: metalLayer) else {
                print("[DotLottieWebGPUView] Failed to create WebGPU context")
                return
            }
            wgpuContext = ctx
            metalLayer.drawableSize = physical
            configuredSize = physical
        } else if physical != configuredSize {
            // Resize: drain in-flight GPU work before ThorVG releases its render
            // targets and reconfigures the surface, otherwise a Staging buffer can
            // be freed while a pending Signal command buffer still references it
            // (Metal: notifyExternalReferencesNonZeroOnDealloc).
            wgpuContext?.waitUntilIdle()
            metalLayer.drawableSize = physical
            configuredSize = physical
        } else {
            return
        }

        guard let ctx = wgpuContext else { return }
        _ = bridge.setWebGPUTarget(
            device: ctx.devicePtr,
            instance: ctx.instancePtr,
            target: ctx.surfacePtr,
            width: w,
            height: h
        )

        // Run any animation load that was deferred waiting for the canvas.
        if let load = pendingLoad {
            pendingLoad = nil
            _ = load()
        }
    }

    // MARK: - Render loop

#if os(iOS)
    private func startDisplayLink() {
        let proxy = DisplayLinkProxy(target: self)
        displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.onDisplayLink(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc fileprivate func onDisplayLink(_ link: CADisplayLink) {
        performTick()
    }

#elseif os(macOS)
    private func startDisplayLink() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1.0 / 60.0, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in self?.performTick() }
        timer.resume()
        displayTimer = timer
    }

    private func stopDisplayLink() {
        displayTimer?.cancel()
        displayTimer = nil
    }
#endif

    private func performTick() {
        guard wgpuContext != nil else { return }
        let now = CACurrentMediaTime()
        let dt = lastTickTime == 0 ? 0.0 : Float((now - lastTickTime) * 1000.0)
        lastTickTime = now

        // Wrap render+present in an explicit autorelease pool so that wgpu-native's
        // "(wgpu internal) Signal" MTLCommandBuffers — created by every wgpuQueueSubmit
        // for GPU completion tracking — are released before the next frame's submit
        // tries to recycle their associated Staging buffers.  Without this, Metal
        // Debug fires -[MTLDebugDevice notifyExternalReferencesNonZeroOnDealloc:]
        // because the Signal ObjC object (in the run-loop pool) still holds a Metal
        // retain on the Staging buffer when wgpu recycles it.
        autoreleasepool {
            if bridge.tick(dt: dt) {
                wgpuContext?.present()
            }
        }
    }

    // MARK: - Gesture handling (state machine input)

    private func setupGestures() {
#if os(iOS)
        isUserInteractionEnabled = true
        let gm = GestureManager()
        gm.gestureManagerDelegate = self
        addGestureRecognizer(gm)
        gestureManager = gm
#elseif os(macOS)
        let gm = GestureManager()
        gm.gestureManagerDelegate = self
        gestureManager = gm
#endif
    }

#if os(macOS)
    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = mouseTrackingArea { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        mouseTrackingArea = area
    }

    private func locationInView(_ event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    override public func mouseDown(with event: NSEvent)    { gestureManager?.handleMouseDown(at: locationInView(event)) }
    override public func mouseDragged(with event: NSEvent) { gestureManager?.handleMouseDragged(at: locationInView(event)) }
    override public func mouseUp(with event: NSEvent)      { gestureManager?.handleMouseUp(at: locationInView(event)) }
    override public func mouseMoved(with event: NSEvent)   { gestureManager?.handleMouseMoved(at: locationInView(event)) }
    override public func mouseEntered(with event: NSEvent) { gestureManager?.handleMouseEntered(at: locationInView(event)) }
    override public func mouseExited(with event: NSEvent)  { gestureManager?.handleMouseExited(at: locationInView(event)) }
#endif

    /// Post a state-machine pointer event, mapping the gesture (in view points) to
    /// the running state machine. No-op when no state machine is running.
    private func postPointerEvent(_ makeEvent: (_ x: Float, _ y: Float) -> Event, at location: CGPoint) {
        guard bridge.isStateMachineRunning else { return }
        let mapped = mapCoordinatesToAnimation(location)
        bridge.stateMachinePostEvent(event: makeEvent(Float(mapped.x), Float(mapped.y)))
    }

    /// Maps a view-space point (in points) to the WebGPU render target's pixel
    /// space, which is the coordinate space the state machine hit-tests in.
    ///
    /// Unlike the software renderer (which loads at a fixed pixel size and maps to
    /// that), the WebGPU path renders straight into the surface, whose size is the
    /// physical drawable size we set via `setWebGPUTarget` (`bounds × displayScale`,
    /// stored in `configuredSize`). So we map view points to that surface space.
    /// On macOS the Y axis is flipped (AppKit origin is bottom-left, surface is
    /// top-left), matching the software path.
    private func mapCoordinatesToAnimation(_ point: CGPoint) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else { return point }

        let target = configuredSize == .zero
            ? CGSize(width: bounds.width * displayScale, height: bounds.height * displayScale)
            : configuredSize
        let scaleX = target.width / bounds.width
        let scaleY = target.height / bounds.height

#if os(iOS)
        return CGPoint(x: point.x * scaleX, y: point.y * scaleY)
#elseif os(macOS)
        let flippedY = bounds.height - point.y
        return CGPoint(x: point.x * scaleX, y: flippedY * scaleY)
#endif
    }

    // MARK: - Public API

    /// Direct access to the underlying player, exposing the full
    /// state-machine / playback API (`stateMachineSetNumericInput`, `seek`, etc.)
    /// without mirroring every method on this view.
    public var player: DotLottiePlayer { bridge }

    /// Load a .json or .lottie file from the given bundle.
    /// If the WebGPU canvas is not yet ready (no layout pass), loading is deferred
    /// until the canvas exists. The WebGPU canvas must exist before animation data
    /// is added (ThorVG requirement: set_wg_target before load).
    @discardableResult
    public func loadAnimation(fileName: String, bundle: Bundle = .main) -> Bool {
        reconfigureWebGPUIfNeeded()
        if wgpuContext != nil {
            return loadAnimationImmediate(fileName: fileName, bundle: bundle)
        }
        pendingLoad = { [weak self] in
            self?.loadAnimationImmediate(fileName: fileName, bundle: bundle) ?? false
        }
        return true
    }

    /// Load a .json or .lottie animation from a remote URL.
    ///
    /// The file is fetched asynchronously; once downloaded it is handed to the
    /// existing load path (which defers until the WebGPU canvas is ready). The
    /// extension is inferred from the URL: a path containing `.lottie` is loaded
    /// as dotLottie data, otherwise the body is treated as Lottie JSON.
    ///
    /// - Returns: `true` if the URL was valid and a fetch was started; the actual
    ///   load result is delivered through the player's `Observer` (`onLoad` /
    ///   `onLoadError`). Subscribe via `subscribe(observer:)` to observe it.
    @discardableResult
    public func loadAnimation(webURL: String) -> Bool {
        guard let url = URL(string: webURL) else { return false }
        Task { [weak self] in
            let data: Data
            do {
                data = try await fetchFileFromURL(url: url)
            } catch {
                print("[DotLottieWebGPUView] Failed to load animation from URL: \(error)")
                return
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                if webURL.contains(".lottie") {
                    self.loadDotlottie(data: data)
                } else {
                    self.loadAnimationData(String(decoding: data, as: UTF8.self))
                }
            }
        }
        return true
    }

    private func loadAnimationImmediate(fileName: String, bundle: Bundle) -> Bool {
        if let url = bundle.url(forResource: fileName, withExtension: "json"),
           let data = try? String(contentsOf: url) {
            return finishLoad(bridge.loadAnimationData(animationData: data))
        }
        if let url = bundle.url(forResource: fileName, withExtension: "lottie"),
           let data = try? Data(contentsOf: url) {
            return finishLoad(bridge.loadDotlottieData(fileData: data))
        }
        return false
    }

    @discardableResult
    public func loadAnimationData(_ animationData: String) -> Bool {
        reconfigureWebGPUIfNeeded()
        if wgpuContext != nil {
            return loadAnimationDataImmediate(animationData)
        }
        pendingLoad = { [weak self] in
            self?.loadAnimationDataImmediate(animationData) ?? false
        }
        return true
    }

    private func loadAnimationDataImmediate(_ animationData: String) -> Bool {
        finishLoad(bridge.loadAnimationData(animationData: animationData))
    }

    @discardableResult
    public func loadDotlottie(data: Data) -> Bool {
        reconfigureWebGPUIfNeeded()
        if wgpuContext != nil {
            return loadDotlottieImmediate(data)
        }
        pendingLoad = { [weak self, data] in
            self?.loadDotlottieImmediate(data) ?? false
        }
        return true
    }

    private func loadDotlottieImmediate(_ data: Data) -> Bool {
        finishLoad(bridge.loadDotlottieData(fileData: data))
    }

    /// Common post-load work: auto-start a state machine named in the config, then
    /// draw the first frame so something is visible even when `autoplay` is false
    /// (the display link only presents while the animation is advancing).
    @discardableResult
    private func finishLoad(_ ok: Bool) -> Bool {
        guard ok else { return false }
        if !config.stateMachineId.isEmpty {
            _ = bridge.stateMachineLoad(stateMachineId: config.stateMachineId)
            _ = bridge.stateMachineStart()
        }
        renderCurrentFrame()
        return true
    }

    /// Render the current frame once and present it. Used to show the initial
    /// frame after load when the animation is not playing.
    private func renderCurrentFrame() {
        guard wgpuContext != nil else { return }
        autoreleasepool {
            if bridge.render() {
                wgpuContext?.present()
            }
        }
    }

    @discardableResult public func play()  -> Bool { bridge.play() }
    @discardableResult public func pause() -> Bool { bridge.pause() }
    @discardableResult public func stop()  -> Bool { bridge.stop() }

    public var isLoaded:   Bool { bridge.isLoaded() }
    public var isPlaying:  Bool { bridge.isPlaying() }
    public var isPaused:   Bool { bridge.isPaused() }

    public func subscribe(observer: Observer)   { bridge.subscribe(observer: observer) }
    public func unsubscribe(observer: Observer) { bridge.unsubscribe(observer: observer) }

    // MARK: - State machine

    @discardableResult
    public func stateMachineLoad(id: String) -> Bool { bridge.stateMachineLoad(stateMachineId: id) }

    @discardableResult
    public func stateMachineLoadData(_ data: String) -> Bool { bridge.stateMachineLoadData(stateMachine: data) }

    @discardableResult
    public func stateMachineStart(openUrlPolicy: OpenUrlPolicy = OpenUrlPolicy()) -> Bool {
        bridge.stateMachineStart(openUrlPolicy: openUrlPolicy)
    }

    @discardableResult
    public func stateMachineStop() -> Bool { bridge.stateMachineStop() }

    @discardableResult
    public func stateMachineSubscribe(observer: StateMachineObserver) -> Bool {
        bridge.stateMachineSubscribe(observer: observer)
    }

    @discardableResult
    public func stateMachineUnsubscribe(observer: StateMachineObserver) -> Bool {
        bridge.stateMachineUnsubscribe(observer: observer)
    }

    // MARK: - Deinit

    deinit {
        stopDisplayLink()
        if let ctx = wgpuContext {
            // Drain in-flight GPU work before releasing anything, so no pending
            // Signal command buffer outlives the Staging buffers it references.
            ctx.waitUntilIdle()

            // Tell ThorVG to release its GPU resources first. ThorVG stores the
            // wgpu device/surface as raw unowned pointers, so its destructor would
            // use them after we've freed them. Passing nil triggers WgRenderer::release()
            // which zeroes out mContext.queue — ThorVG's destructor then exits early.
            _ = bridge.setWebGPUTarget(device: nil, instance: nil, target: nil, width: 0, height: 0)

            // Releasing the context (WgpuContext.deinit) drains the GPU queue and
            // releases the device and its internal staging buffers.
            wgpuContext = nil
        }
    }
}

// MARK: - GestureManagerDelegate

extension DotLottieWebGPUView: GestureManagerDelegate {
    func gestureManagerDidRecognizeDown(_ gestureManager: GestureManager, at location: CGPoint) {
        postPointerEvent(Event.pointerDown, at: location)
    }

    func gestureManagerDidRecognizeMove(_ gestureManager: GestureManager, at location: CGPoint) {
        postPointerEvent(Event.pointerMove, at: location)
    }

    func gestureManagerDidRecognizeUp(_ gestureManager: GestureManager, at location: CGPoint) {
        postPointerEvent(Event.pointerUp, at: location)
    }

    func gestureManagerDidRecognizeTap(_ gestureManager: GestureManager, at location: CGPoint) {
        postPointerEvent(Event.click, at: location)
    }

#if os(macOS)
    func gestureManagerDidRecognizeHover(_ gestureManager: GestureManager, at location: CGPoint) {
        postPointerEvent(Event.pointerEnter, at: location)
    }

    func gestureManagerDidRecognizeExitHover(_ gestureManager: GestureManager, at location: CGPoint) {
        postPointerEvent(Event.pointerExit, at: location)
    }
#endif
}

#if os(iOS)
/// Weak proxy used as the CADisplayLink target to avoid a retain cycle.
private final class DisplayLinkProxy {
    private weak var target: DotLottieWebGPUView?

    init(target: DotLottieWebGPUView) {
        self.target = target
    }

    @objc func onDisplayLink(_ link: CADisplayLink) {
        target?.onDisplayLink(link)
    }
}
#endif

#endif
