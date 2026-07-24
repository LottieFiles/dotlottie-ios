#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
import Metal
import MetalKit
import CoreImage
import Combine

public typealias PlatformView = UIView
public typealias PlatformColor = UIColor
#elseif os(macOS)
import AppKit
import Metal
import MetalKit
import CoreImage
import Combine

public typealias PlatformView = NSView
public typealias PlatformColor = NSColor
#endif

#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)

@IBDesignable
open class DotLottiePlayerUIView: PlatformView {
    
    // MARK: - Public Properties
    
    /// The dotlottie animation backing this view
    public var dotLottieAnimation: DotLottieAnimation? {
        didSet {
            setupAnimation()
        }
    }
    
    /// The configuration used by the animation
    public var config: AnimationConfig {
        didSet {
            updateConfig()
        }
    }
    
    /// Whether the animation is currently playing
    public var isAnimationPlaying: Bool {
        dotLottieAnimation?.isPlaying() ?? false
    }
    
    /// Whether the animation is currently paused
    public var isAnimationPaused: Bool {
        dotLottieAnimation?.isPaused() ?? false
    }
    
    /// Whether the animation is currently stopped
    public var isAnimationStopped: Bool {
        dotLottieAnimation?.isStopped() ?? false
    }
    
    /// Loop mode for the animation
    public var loopMode: DotLottieLoopMode {
        get {
            if let dotLottie = dotLottieAnimation {
                return dotLottie.loop() ? .loop : .playOnce
            }
            return .playOnce
        }
        set {
            dotLottieAnimation?.setLoop(loop: newValue == .loop)
        }
    }
    
    /// Animation playback speed (1.0 = normal speed)
    public var animationSpeed: CGFloat {
        get {
            CGFloat(dotLottieAnimation?.speed() ?? 1.0)
        }
        set {
            dotLottieAnimation?.setSpeed(speed: Float(newValue))
        }
    }
    
    /// Current animation progress (0.0 to 1.0)
    public var currentProgress: CGFloat {
        get {
            CGFloat(dotLottieAnimation?.currentProgress() ?? 0.0)
        }
        set {
            let clamped = max(0.0, min(1.0, newValue))
            _ = dotLottieAnimation?.setProgress(progress: Float(clamped))
        }
    }
    
    /// Current animation frame
    public var currentFrame: CGFloat {
        get {
            CGFloat(dotLottieAnimation?.currentFrame() ?? 0.0)
        }
        set {
            _ = dotLottieAnimation?.setFrame(frame: Float(newValue))
        }
    }
    
    /// Total frames in the animation
    public var totalFrames: CGFloat {
        CGFloat(dotLottieAnimation?.totalFrames() ?? 0.0)
    }
    
    /// Duration of the animation in seconds
    public var duration: TimeInterval {
        TimeInterval(dotLottieAnimation?.duration() ?? 0.0)
    }
    
    /// A closure that is called when the animation is loaded
    public var animationLoaded: ((_ playerView: DotLottiePlayerUIView, _ animation: DotLottieAnimation?) -> Void)?
    
    /// Animation playback mode
    public var mode: Mode {
        get {
            dotLottieAnimation?.mode() ?? .forward
        }
        set {
            dotLottieAnimation?.setMode(mode: newValue)
        }
    }
    
    /// Whether frame interpolation is enabled
    public var useFrameInterpolation: Bool {
        get {
            dotLottieAnimation?.useFrameInterpolation() ?? false
        }
        set {
            dotLottieAnimation?.setFrameInterpolation(newValue)
        }
    }
    
    /// Animation segments (start, end) for partial playback
    public var segments: (Float, Float)? {
        get {
            let segs = dotLottieAnimation?.segments() ?? (0, 0)
            return (segs.0, segs.1)
        }
        set {
            if let segments = newValue {
                dotLottieAnimation?.setSegments(segments: segments)
            }
        }
    }
    
    /// Intrinsic content size based on animation dimensions
    public override var intrinsicContentSize: CGSize {
        if let dotLottie = dotLottieAnimation {
            let width = dotLottie.animationModel.width
            let height = dotLottie.animationModel.height
            return CGSize(width: width, height: height)
        }
        #if canImport(UIKit)
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        #else
        return CGSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        #endif
    }
    
    // MARK: - Private Properties
    
    private var animationView: DotLottieAnimationView?
    private var cancellables = Set<AnyCancellable>()
    private var loadingObserver: AnyCancellable?
    private var loadingAttempts = 0
    #if canImport(UIKit)
    private var gestureManager: GestureManager?
    #elseif canImport(AppKit)
    private var gestureManager: GestureManager?
    #endif
    
    // MARK: - Initialization
    
    /// Initializes with a dotlottie animation and configuration
    public init(
        dotLottieAnimation: DotLottieAnimation? = nil,
        config: AnimationConfig = AnimationConfig()
    ) {
        self.config = config
        self.dotLottieAnimation = dotLottieAnimation
        super.init(frame: .zero)
        commonInit()
        setupAnimation()
    }
    
    /// Initializes with a file name from bundle
    public convenience init(
        name: String,
        bundle: Bundle = .main,
        config: AnimationConfig = AnimationConfig(),
        completion: ((DotLottiePlayerUIView, Error?) -> Void)? = nil
    ) {
        let animation = DotLottieAnimation(fileName: name, bundle: bundle, config: config)
        self.init(dotLottieAnimation: animation, config: config)
        
        // Wait for animation to load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if animation.isLoaded() {
                self.animationLoaded?(self, animation)
                completion?(self, nil)
            } else if animation.error() {
                completion?(self, NSError(domain: "DotLottieError", code: -1, userInfo: [NSLocalizedDescriptionKey: animation.errorMessage()]))
            }
        }
    }
    
    /// Initializes with a file path
    public convenience init(
        filePath: String,
        config: AnimationConfig = AnimationConfig(),
        completion: ((DotLottiePlayerUIView, Error?) -> Void)? = nil
    ) {
        // For file path, we need to load the data first
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            self.init(dotLottieAnimation: nil, config: config)
            completion?(self, NSError(domain: "DotLottieError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load file at path: \(filePath)"]))
            return
        }
        
        let animation = DotLottieAnimation(lottieData: data, config: config)
        self.init(dotLottieAnimation: animation, config: config)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if animation.isLoaded() {
                self.animationLoaded?(self, animation)
                completion?(self, nil)
            } else if animation.error() {
                completion?(self, NSError(domain: "DotLottieError", code: -1, userInfo: [NSLocalizedDescriptionKey: animation.errorMessage()]))
            }
        }
    }
    
    /// Initializes with a URL
    public convenience init(
        url: URL,
        config: AnimationConfig = AnimationConfig(),
        session: URLSession = .shared,
        completion: ((DotLottiePlayerUIView, Error?) -> Void)? = nil
    ) {
        let animation = DotLottieAnimation(webURL: url.absoluteString, config: config)
        self.init(dotLottieAnimation: animation, config: config)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if animation.isLoaded() {
                self.animationLoaded?(self, animation)
                completion?(self, nil)
            } else if animation.error() {
                completion?(self, NSError(domain: "DotLottieError", code: -1, userInfo: [NSLocalizedDescriptionKey: animation.errorMessage()]))
            }
        }
    }
    
    /// Initializes with animation data (JSON string)
    public convenience init(
        animationData: String,
        config: AnimationConfig = AnimationConfig()
    ) {
        let animation = DotLottieAnimation(animationData: animationData, config: config)
        self.init(dotLottieAnimation: animation, config: config)
    }
    
    /// Initializes with dotlottie data
    public convenience init(
        dotLottieData: Data,
        config: AnimationConfig = AnimationConfig()
    ) {
        let animation = DotLottieAnimation(dotLottieData: dotLottieData, config: config)
        self.init(dotLottieAnimation: animation, config: config)
    }
    
    public override init(frame: CGRect) {
        self.config = AnimationConfig()
        super.init(frame: frame)
        commonInit()
    }
    
    required public init?(coder: NSCoder) {
        self.config = AnimationConfig()
        super.init(coder: coder)
        commonInit()
    }
    
    // MARK: - Setup
    
    private func commonInit() {
        #if canImport(UIKit)
        contentMode = .scaleAspectFit
        clipsToBounds = true
        backgroundColor = .clear
        #else
        wantsLayer = true
        layer?.masksToBounds = true
        #endif
    }
    
    private func setupAnimation() {
        // Remove old animation view
        animationView?.removeFromSuperview()
        loadingObserver?.cancel()
        
        guard let dotLottie = dotLottieAnimation else {
            animationView = nil
            invalidateIntrinsicContentSize()
            return
        }
        
        // Create new animation view
        let view = DotLottieAnimationView(dotLottieViewModel: dotLottie)
        #if canImport(UIKit)
        view.isUserInteractionEnabled = true
        // Keep the view interactive
        bringSubviewToFront(view)
        #endif
        animationView = view
        addSubview(view)
        
        // Set up frame and ensure it fits properly
        view.frame = bounds
        #if canImport(UIKit)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.contentMode = contentMode // Inherit content mode from parent
        view.clipsToBounds = true
        #else
        view.autoresizingMask = [.width, .height]
        #endif
        
        // Update config
        updateConfig()
        
        // Set up loading observer
        setupLoadingObserver(for: dotLottie)
        
        // Set up interaction recognizers
        #if canImport(UIKit) || canImport(AppKit)
        setupInteractionRecognizers()
        #endif
        
        // Call animation loaded callback if animation is already loaded
        if dotLottie.isLoaded() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.animationLoaded?(self, dotLottie)
                self.invalidateIntrinsicContentSize()
                // Ensure proper layout after loading
                #if canImport(UIKit)
                self.setNeedsLayout()
                self.layoutIfNeeded()
                #else
                self.needsLayout = true
                self.layoutSubtreeIfNeeded()
                #endif
            }
        }
    }
    
    private func setupLoadingObserver(for dotLottie: DotLottieAnimation) {
        // Poll for loading status since DotLottieAnimation doesn't expose a publisher for isLoaded
        loadingAttempts = 0
        let maxAttempts = 100 // 10 seconds max wait
        
        let timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let dotLottie = self.dotLottieAnimation else { return }
                
                self.loadingAttempts += 1
                
                if dotLottie.isLoaded() {
                    self.loadingObserver?.cancel()
                    self.loadingObserver = nil
                    self.animationLoaded?(self, dotLottie)
                    self.invalidateIntrinsicContentSize()
                } else if dotLottie.error() || self.loadingAttempts >= maxAttempts {
                    self.loadingObserver?.cancel()
                    self.loadingObserver = nil
                    if dotLottie.error() {
                        self.animationLoaded?(self, nil)
                    }
                }
            }
        
        loadingObserver = timerCancellable
    }
    
    private func updateConfig() {
        guard let dotLottie = dotLottieAnimation else { return }
        
        if let loop = config.loop {
            dotLottie.setLoop(loop: loop)
        }
        if let speed = config.speed {
            dotLottie.setSpeed(speed: speed)
        }
        if let autoplay = config.autoplay {
            dotLottie.setAutoplay(autoplay: autoplay)
        }
        if let mode = config.mode {
            dotLottie.setMode(mode: mode)
        }
        if let segments = config.segments {
            dotLottie.setSegments(segments: segments)
        }
        if let marker = config.marker, !marker.isEmpty {
            dotLottie.setMarker(marker: marker)
        }
    }
    
    #if canImport(UIKit)
    public override func layoutSubviews() {
        super.layoutSubviews()
        layoutAnimation()
    }
    
    public override var contentMode: UIView.ContentMode {
        didSet {
            animationView?.contentMode = contentMode
        }
    }
    #else
    public override func layout() {
        super.layout()
        layoutAnimation()
    }
    #endif
    
    private func layoutAnimation() {
        guard let animationView = animationView else { return }
        
        // Always match the parent bounds
        animationView.frame = bounds
        #if canImport(UIKit)
        animationView.setNeedsLayout()
        animationView.layoutIfNeeded()
        // Ensure content mode is synchronized
        if animationView.contentMode != contentMode {
            animationView.contentMode = contentMode
        }
        #elseif canImport(AppKit)
        animationView.needsLayout = true
        animationView.layoutSubtreeIfNeeded()
        // Update tracking areas when view is resized
        setupTrackingAreas()
        #endif
        // Don't resize animation - let it use its natural size like the legacy implementation
        // resizeAnimationIfNeeded()
    }

    #if canImport(UIKit)
    private func setupInteractionRecognizers() {
        guard gestureManager == nil else {
            return
        }
        
        isUserInteractionEnabled = true
        
        guard let animationView = animationView else {
            return
        }
        
        animationView.isUserInteractionEnabled = true
        
        let gm = GestureManager()
        gm.cancelsTouchesInView = false
        gm.delegate = self
        gm.gestureManagerDelegate = self
        addGestureRecognizer(gm)
        animationView.addGestureRecognizer(gm)
        gestureManager = gm
    }
    #elseif canImport(AppKit)
    private func setupInteractionRecognizers() {
        guard gestureManager == nil else { return }
        
        let gm = GestureManager()
        gm.gestureManagerDelegate = self
        gestureManager = gm
        
        // Set up tracking areas for mouse events
        setupTrackingAreas()
    }
    
    private func setupTrackingAreas() {
        // Remove existing tracking areas
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        // Add new tracking area for hover detection
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let location = convert(event.locationInWindow, from: nil)
        gestureManager?.handleMouseDown(at: location)
    }
    
    public override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        let location = convert(event.locationInWindow, from: nil)
        gestureManager?.handleMouseDragged(at: location)
    }
    
    public override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let location = convert(event.locationInWindow, from: nil)
        gestureManager?.handleMouseUp(at: location)
    }
    
    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let location = convert(event.locationInWindow, from: nil)
        gestureManager?.handleMouseMoved(at: location)
    }
    
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        let location = convert(event.locationInWindow, from: nil)
        gestureManager?.handleMouseEntered(at: location)
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        let location = convert(event.locationInWindow, from: nil)
        gestureManager?.handleMouseExited(at: location)
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingAreas()
    }
    #endif
    
    // MARK: - Playback Control
    
    private func resizeAnimationIfNeeded() {
        #if canImport(UIKit)
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 2.0
        #else
        let scale: CGFloat = 1.0
        #endif
        guard let dotLottieAnimation else { return }
        let targetWidth = max(Int(bounds.width * scale), 1)
        let targetHeight = max(Int(bounds.height * scale), 1)
        let currentWidth = dotLottieAnimation.animationModel.width
        let currentHeight = dotLottieAnimation.animationModel.height
        if currentWidth != targetWidth || currentHeight != targetHeight {
            dotLottieAnimation.resize(width: targetWidth, height: targetHeight)
        }
    }
    
    /// Plays the animation
    @discardableResult
    public func play() -> Bool {
        dotLottieAnimation?.play() ?? false
    }
    
    /// Plays the animation from a specific frame
    @discardableResult
    public func play(fromFrame frame: Float) -> Bool {
        dotLottieAnimation?.play(fromFrame: frame) ?? false
    }
    
    /// Plays the animation from a specific progress (0.0 to 1.0)
    @discardableResult
    public func play(fromProgress progress: Float) -> Bool {
        dotLottieAnimation?.play(fromProgress: progress) ?? false
    }
    
    /// Plays the animation from a progress to a progress
    @discardableResult
    public func play(fromProgress: Float, toProgress: Float, loopMode: DotLottieLoopMode? = nil) -> Bool {
        guard let dotLottie = dotLottieAnimation else { return false }
        
        // Set segments for the play range
        let startFrame = fromProgress * Float(dotLottie.totalFrames())
        let endFrame = toProgress * Float(dotLottie.totalFrames())
        dotLottie.setSegments(segments: (startFrame, endFrame))
        
        // Set loop mode if provided
        if let loopMode = loopMode {
            dotLottie.setLoop(loop: loopMode == .loop)
        }
        
        // Set frame and play
        _ = dotLottie.setFrame(frame: startFrame)
        return dotLottie.play()
    }
    
    /// Plays the animation from a frame to a frame
    @discardableResult
    public func play(fromFrame: Float, toFrame: Float, loopMode: DotLottieLoopMode? = nil) -> Bool {
        guard let dotLottie = dotLottieAnimation else { return false }
        
        // Set segments for the play range
        dotLottie.setSegments(segments: (fromFrame, toFrame))
        
        // Set loop mode if provided
        if let loopMode = loopMode {
            dotLottie.setLoop(loop: loopMode == .loop)
        }
        
        // Set frame and play
        _ = dotLottie.setFrame(frame: fromFrame)
        return dotLottie.play()
    }
    
    /// Plays the animation from a marker
    @discardableResult
    public func play(marker: String, loopMode: DotLottieLoopMode? = nil) -> Bool {
        guard let dotLottie = dotLottieAnimation else { return false }
        
        // Find marker
        let markers = dotLottie.markers()
        guard let targetMarker = markers.first(where: { $0.name == marker }) else {
            return false
        }
        
        // Set marker and loop mode
        dotLottie.setMarker(marker: marker)
        if let loopMode = loopMode {
            dotLottie.setLoop(loop: loopMode == .loop)
        }
        
        // Set frame to marker time and play
        _ = dotLottie.setFrame(frame: targetMarker.time)
        return dotLottie.play()
    }
    
    /// Plays the animation from a marker to another marker
    @discardableResult
    public func play(fromMarker: String?, toMarker: String, loopMode: DotLottieLoopMode? = nil) -> Bool {
        guard let dotLottie = dotLottieAnimation else { return false }
        
        let markers = dotLottie.markers()
        guard let endMarker = markers.first(where: { $0.name == toMarker }) else {
            return false
        }
        
        let startTime: Float
        if let fromMarker = fromMarker, let startMarker = markers.first(where: { $0.name == fromMarker }) {
            startTime = startMarker.time
        } else {
            startTime = dotLottie.currentFrame()
        }
        
        let endTime = endMarker.time + endMarker.duration
        
        // Set segments
        dotLottie.setSegments(segments: (startTime, endTime))
        
        // Set loop mode if provided
        if let loopMode = loopMode {
            dotLottie.setLoop(loop: loopMode == .loop)
        }
        
        // Set frame and play
        _ = dotLottie.setFrame(frame: startTime)
        return dotLottie.play()
    }
    
    /// Pauses the animation
    @discardableResult
    public func pause() -> Bool {
        dotLottieAnimation?.pause() ?? false
    }
    
    /// Stops the animation
    @discardableResult
    public func stop() -> Bool {
        dotLottieAnimation?.stop() ?? false
    }
    
    // MARK: - Frame/Progress Control
    
    /// Sets the current frame
    @discardableResult
    public func setFrame(_ frame: Float) -> Bool {
        dotLottieAnimation?.setFrame(frame: frame) ?? false
    }
    
    /// Sets the current progress (0.0 to 1.0)
    @discardableResult
    public func setProgress(_ progress: Float) -> Bool {
        dotLottieAnimation?.setProgress(progress: progress) ?? false
    }
    
    // MARK: - Animation Info
    
    /// Loads an animation by ID from the current dotlottie file
    public func loadAnimation(byId animationId: String) throws {
        try dotLottieAnimation?.loadAnimationById(animationId)
    }
    
    /// Gets the manifest from the dotlottie file
    public func manifest() -> Manifest? {
        dotLottieAnimation?.manifest()
    }
    
    /// Gets markers from the animation
    public func markers() -> [Marker] {
        dotLottieAnimation?.markers() ?? []
    }
    
    /// Sets a marker to play
    public func setMarker(_ marker: String) {
        dotLottieAnimation?.setMarker(marker: marker)
    }
    
    /// Returns the progress time for a marker, or nil if not found
    public func progressTime(forMarker named: String) -> CGFloat? {
        guard let dotLottie = dotLottieAnimation else { return nil }
        let markers = dotLottie.markers()
        guard let marker = markers.first(where: { $0.name == named }) else {
            return nil
        }
        let totalFrames = dotLottie.totalFrames()
        guard totalFrames > 0 else { return nil }
        return CGFloat(marker.time / totalFrames)
    }
    
    /// Returns the frame time for a marker, or nil if not found
    public func frameTime(forMarker named: String) -> CGFloat? {
        guard let dotLottie = dotLottieAnimation else { return nil }
        let markers = dotLottie.markers()
        guard let marker = markers.first(where: { $0.name == named }) else {
            return nil
        }
        return CGFloat(marker.time)
    }
    
    /// Returns the duration frame time for a marker, or nil if not found
    public func durationFrameTime(forMarker named: String) -> CGFloat? {
        guard let dotLottie = dotLottieAnimation else { return nil }
        let markers = dotLottie.markers()
        guard let marker = markers.first(where: { $0.name == named }) else {
            return nil
        }
        return CGFloat(marker.duration)
    }
    
    // MARK: - State Machine Support
    
    /// Checks if animation supports state machine
    public func isStateMachine() -> Bool {
        manifest()?.stateMachines?.isEmpty == false
    }
    
    /// Loads a state machine by ID
    @discardableResult
    public func stateMachineLoad(id: String) -> Bool {
        dotLottieAnimation?.stateMachineLoad(id: id) ?? false
    }
    
    /// Loads state machine data from a JSON string
    @discardableResult
    public func stateMachineLoadData(_ data: String) -> Bool {
        dotLottieAnimation?.stateMachineLoadData(data) ?? false
    }
    
    /// Starts the state machine
    @discardableResult
    public func stateMachineStart() -> Bool {
        dotLottieAnimation?.stateMachineStart() ?? false
    }

    /// Loads and starts the given state machine from the manifest.
    /// This stops any running state machine before starting the requested one.
    @discardableResult
    public func startStateMachine(id: String, openUrlPolicy: OpenUrlPolicy = OpenUrlPolicy()) -> Bool {
        guard let dotLottieAnimation else { return false }
        return dotLottieAnimation.stateMachineStart(id: id, openUrlPolicy: openUrlPolicy)
    }
    
    /// Stops the state machine
    @discardableResult
    public func stateMachineStop() -> Bool {
        dotLottieAnimation?.stateMachineStop() ?? false
    }
    
    /// Posts an event to the state machine
    public func stateMachinePostEvent(_ event: Event, force: Bool = false) {
        dotLottieAnimation?.stateMachinePostEvent(event, force: force)
    }
    
    /// Posts a click event at the given coordinates
    public func stateMachinePostClickEvent(at point: CGPoint) {
        let mapped = mapCoordinatesToAnimation(point)
        dotLottieAnimation?.stateMachinePostEvent(.click(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    /// Posts a pointer down event
    public func stateMachinePostPointerDownEvent(at point: CGPoint) {
        let mapped = mapCoordinatesToAnimation(point)
        dotLottieAnimation?.stateMachinePostEvent(.pointerDown(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    /// Posts a pointer up event
    public func stateMachinePostPointerUpEvent(at point: CGPoint) {
        let mapped = mapCoordinatesToAnimation(point)
        dotLottieAnimation?.stateMachinePostEvent(.pointerUp(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    /// Posts a pointer move event
    public func stateMachinePostPointerMoveEvent(at point: CGPoint) {
        let mapped = mapCoordinatesToAnimation(point)
        dotLottieAnimation?.stateMachinePostEvent(.pointerMove(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    /// Posts a pointer enter event
    public func stateMachinePostPointerEnterEvent(at point: CGPoint) {
        let mapped = mapCoordinatesToAnimation(point)
        dotLottieAnimation?.stateMachinePostEvent(.pointerEnter(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    /// Posts a pointer exit event
    public func stateMachinePostPointerExitEvent(at point: CGPoint) {
        let mapped = mapCoordinatesToAnimation(point)
        dotLottieAnimation?.stateMachinePostEvent(.pointerExit(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    /// Maps view coordinates to animation coordinates (for state machine events)
    /// This matches the legacy Coordinator's calculateCoordinates method exactly
    private func mapCoordinatesToAnimation(_ point: CGPoint) -> CGPoint {
        guard let animation = dotLottieAnimation else { return point }
        
        // Animation dimensions in pixels (original, not resized)
        let animationWidth = CGFloat(animation.animationModel.width)
        let animationHeight = CGFloat(animation.animationModel.height)
        
        #if canImport(UIKit)
        // For iOS, Coordinator uses drawableSize (in pixels) which equals bounds.size * screenScale
        // This is what viewSize represents in Coordinator's calculateCoordinates for iOS
        let screenScale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 2.0
        let viewSize = CGSize(width: bounds.size.width * screenScale, height: bounds.size.height * screenScale)
        
        guard viewSize.width > 0, viewSize.height > 0 else { return point }
        
        // Calculate scale ratio: animation pixels / view pixels (drawableSize)
        // This matches the legacy Coordinator's approach exactly
        let scaleRatio = CGPoint(
            x: animationWidth / viewSize.width,
            y: animationHeight / viewSize.height
        )
        
        // Convert from view coordinates (points) to animation coordinates (pixels)
        // Multiply by scale ratio and screen scale to get pixel coordinates
        let mappedX = point.x * scaleRatio.x * screenScale
        let mappedY = point.y * scaleRatio.y * screenScale
        #elseif canImport(AppKit)
        // For macOS, Coordinator uses bounds.size (in points) for viewSize
        let viewSize = bounds.size
        
        guard viewSize.width > 0, viewSize.height > 0 else { return point }
        
        // Calculate scale ratio: animation pixels / view points
        let scaleRatio = CGPoint(
            x: animationWidth / viewSize.width,
            y: animationHeight / viewSize.height
        )
        
        // macOS - Flip Y coordinate (origin is bottom-left on macOS, top-left in animation space)
        let flippedY = viewSize.height - point.y
        
        // Convert from view coordinates (points) to animation coordinates (pixels)
        // scaleRatio already accounts for pixel density since animation is in pixels
        let mappedX = point.x * scaleRatio.x
        let mappedY = flippedY * scaleRatio.y
        #else
        let viewSize = bounds.size
        
        guard viewSize.width > 0, viewSize.height > 0 else { return point }
        
        let scaleRatio = CGPoint(
            x: animationWidth / viewSize.width,
            y: animationHeight / viewSize.height
        )
        
        let mappedX = point.x * scaleRatio.x
        let mappedY = point.y * scaleRatio.y
        #endif
        
        return CGPoint(x: mappedX, y: mappedY)
    }
    
    /// Gets all state machine inputs and their types
    public func stateMachineGetInputs() -> [String: String] {
        dotLottieAnimation?.stateMachineGetInputs() ?? [:]
    }
    
    /// Gets the current state machine state
    public func stateMachineCurrentState() -> String {
        dotLottieAnimation?.stateMachineCurrentState() ?? ""
    }
    
    /// Gets the framework setup events
    public func stateMachineFrameworkSetup() -> [String] {
        dotLottieAnimation?.stateMachineFrameworkSetup() ?? []
    }
    
    /// Sets a numeric input value
    @discardableResult
    public func stateMachineSetNumericInput(key: String, value: Float) -> Bool {
        dotLottieAnimation?.stateMachineSetNumericInput(key: key, value: value) ?? false
    }
    
    /// Sets a boolean input value
    @discardableResult
    public func stateMachineSetBooleanInput(key: String, value: Bool) -> Bool {
        dotLottieAnimation?.stateMachineSetBooleanInput(key: key, value: value) ?? false
    }
    
    /// Sets a string input value
    @discardableResult
    public func stateMachineSetStringInput(key: String, value: String) -> Bool {
        dotLottieAnimation?.stateMachineSetStringInput(key: key, value: value) ?? false
    }
    
    /// Gets a numeric input value
    public func stateMachineGetNumericInput(key: String) -> Float {
        dotLottieAnimation?.stateMachineGetNumericInput(key: key) ?? 0.0
    }
    
    /// Gets a boolean input value
    public func stateMachineGetBooleanInput(key: String) -> Bool {
        dotLottieAnimation?.stateMachineGetBooleanInput(key: key) ?? false
    }
    
    /// Gets a string input value
    public func stateMachineGetStringInput(key: String) -> String {
        dotLottieAnimation?.stateMachineGetStringInput(key: key) ?? ""
    }
    
    /// Subscribe to state machine events
    @discardableResult
    public func stateMachineSubscribe(_ observer: StateMachineObserver) -> Bool {
        dotLottieAnimation?.stateMachineSubscribe(observer) ?? false
    }
    
    /// Unsubscribe from state machine events
    @discardableResult
    public func stateMachineUnsubscribe(_ observer: StateMachineObserver) -> Bool {
        dotLottieAnimation?.stateMachineUnsubscribe(observer) ?? false
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.removeAll()
    }
}

#if os(iOS) || os(tvOS) || os(visionOS)
extension DotLottiePlayerUIView: UIGestureRecognizerDelegate, GestureManagerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
    func gestureManagerDidRecognizeTap(_ gestureManager: GestureManager, at location: CGPoint) {
        // Convert location from gesture recognizer's view coordinate space to self's coordinate space
        let locationInSelf: CGPoint
        if let gestureView = gestureManager.view {
            locationInSelf = convert(location, from: gestureView)
        } else {
            locationInSelf = location
        }
        let mapped = mapCoordinatesToAnimation(locationInSelf)
        stateMachinePostEvent(.click(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    func gestureManagerDidRecognizeMove(_ gestureManager: GestureManager, at location: CGPoint) {
        // Convert location from gesture recognizer's view coordinate space to self's coordinate space
        let locationInSelf: CGPoint
        if let gestureView = gestureManager.view {
            locationInSelf = convert(location, from: gestureView)
        } else {
            locationInSelf = location
        }
        let mapped = mapCoordinatesToAnimation(locationInSelf)
        stateMachinePostEvent(.pointerMove(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    func gestureManagerDidRecognizeDown(_ gestureManager: GestureManager, at location: CGPoint) {
        // Convert location from gesture recognizer's view coordinate space to self's coordinate space
        let locationInSelf: CGPoint
        if let gestureView = gestureManager.view {
            locationInSelf = convert(location, from: gestureView)
        } else {
            locationInSelf = location
        }
        let mapped = mapCoordinatesToAnimation(locationInSelf)
        stateMachinePostEvent(.pointerDown(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    func gestureManagerDidRecognizeUp(_ gestureManager: GestureManager, at location: CGPoint) {
        // Convert location from gesture recognizer's view coordinate space to self's coordinate space
        let locationInSelf: CGPoint
        if let gestureView = gestureManager.view {
            locationInSelf = convert(location, from: gestureView)
        } else {
            locationInSelf = location
        }
        let mapped = mapCoordinatesToAnimation(locationInSelf)
        stateMachinePostEvent(.pointerUp(x: Float(mapped.x), y: Float(mapped.y)))
    }
}
#endif

#if os(macOS)
extension DotLottiePlayerUIView: GestureManagerDelegate {
    func gestureManagerDidRecognizeTap(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = mapCoordinatesToAnimation(location)
        stateMachinePostEvent(.click(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    func gestureManagerDidRecognizeMove(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = mapCoordinatesToAnimation(location)
        stateMachinePostEvent(.pointerMove(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    func gestureManagerDidRecognizeDown(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = mapCoordinatesToAnimation(location)
        stateMachinePostEvent(.pointerDown(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    func gestureManagerDidRecognizeUp(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = mapCoordinatesToAnimation(location)
        stateMachinePostEvent(.pointerUp(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    func gestureManagerDidRecognizeHover(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = mapCoordinatesToAnimation(location)
        stateMachinePostEvent(.pointerEnter(x: Float(mapped.x), y: Float(mapped.y)))
    }
    
    func gestureManagerDidRecognizeExitHover(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = mapCoordinatesToAnimation(location)
        stateMachinePostEvent(.pointerExit(x: Float(mapped.x), y: Float(mapped.y)))
    }
}
#endif

// MARK: - DotLottieLoopMode

public enum DotLottieLoopMode {
    /// Animation is played once then stops
    case playOnce
    /// Animation will loop from beginning to end until stopped
    case loop
}

#endif

