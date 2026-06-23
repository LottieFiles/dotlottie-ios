//
//  DotLottieAnimation.swift
//
//
//  Created by Sam on 31/10/2023.
//

import Foundation
import CoreGraphics
#if !os(watchOS)
import CoreImage
import Metal
#endif

#if os(iOS)
import UIKit
#endif

private class DotLottieAnimationInternalStateMachineObserver: StateMachineInternalObserver {
    func onMessage(message: String) {
        if message.hasPrefix("OpenUrl: ") {
            var url = message.replacingOccurrences(of: "OpenUrl: ", with: "")
            if let dotRange = url.range(of: " |") {
              url.removeSubrange(dotRange.lowerBound..<url.endIndex)
            }
            #if os(iOS)
            if let urlObject = URL(string: url),
               UIApplication.shared.canOpenURL(urlObject) {
                UIApplication.shared.open(urlObject, options: [:], completionHandler: nil)
            }
            #endif
        }
    }
}

// MARK: DotLottieAnimation
public final class DotLottieAnimation: ObservableObject {
    @Published public var framerate: Int = 30
    
    @Published private(set) var player: Player
    
    public var sizeOverrideActive = false
    
    public private(set) var animationModel: AnimationModel = AnimationModel()
    
    private var defaultWidthHeight = 512
    
    internal var config: Config
            
    internal var stateMachineListeners: [String] = []
    
    private var internalStateMachineObserver = DotLottieAnimationInternalStateMachineObserver()

    private var cachedStateMachineInputs: [String: String] = [:]

    private var currFrame = 0

    private var loadingTask: Task<Void, Never>?

    deinit {
        loadingTask?.cancel()
    }

    /// Load directly from a String (.json).
    public convenience init(
        animationData: String,
        config: AnimationConfig,
        threads: Int? = nil
    ) {
        self.init(config: config, threads: threads) {
            try $0.loadAnimation(animationData: animationData)
        } errorMessage: { _ in
            "player failed to load."
        }
    }
    
    /// Load from an animation (.lottie / .json) from the asset bundle.
    public convenience init(
        fileName: String,
        bundle: Bundle = .main,
        config: AnimationConfig,
        threads: Int? = nil
    ) {
        self.init(config: config, threads: threads) {
            try $0.loadAnimationFromBundle(animationName: fileName, bundle: bundle)
        } errorMessage: { error in
            "Loading from bundle failed for both .json and .lottie versions of your animation: \(error)"
        }
    }
    
    /// Load an animation (.lottie / .json) from the web.
    public convenience init(
        webURL: String,
        config: AnimationConfig,
        threads: Int? = nil
    ) {
        self.init(config: config, threads: threads, task: { _ in }, errorMessage: { error in
            "Failed to load dotLottie. Failed with error: \(error)"
        })
        let urlString = webURL
        loadingTask = Task { [weak self] in
            let data: Data
            do {
                guard let url = URL(string: urlString) else { return }
                data = try await fetchFileFromURL(url: url)
            } catch {
                await MainActor.run { [weak self] in
                    self?.animationModel.error = true
                    self?.animationModel.errorMessage = error.localizedDescription
                }
                return
            }

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self else { return }
                do {
                    if urlString.contains(".lottie") {
                        try self.loadDotLottie(data: data)
                    } else {
                        let dataAsString = String(decoding: data, as: UTF8.self)
                        guard !dataAsString.isEmpty else { return }
                        try self.loadAnimation(animationData: dataAsString)
                    }
                } catch {
                    self.animationModel.error = true
                    self.animationModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Load a .lottie file from Data.
    public convenience init(
        dotLottieData: Data,
        config: AnimationConfig,
        threads: Int? = nil
    ) {
        self.init(config: config, threads: threads) {
            try $0.loadDotLottie(data: dotLottieData)
        } errorMessage: { error in
            "Failed to load dotLottie. Failed with error: \(error)"
        }
    }
    
    /// Load a .json or .lottie file from Data
    public convenience init(
        lottieData: Data,
        config: AnimationConfig,
        threads: Int? = nil
    ) {
        self.init(config: config, threads: threads) {
            guard let jsonString = String(data: lottieData, encoding: .utf8) else {
                try $0.loadDotLottie(data: lottieData)
                return
            }
            try $0.loadAnimation(animationData: jsonString)
        } errorMessage: { error in
            "Failed to load dotLottie. Failed with error: \(error)"
        }
    }
    
    @_disfavoredOverload
    @available(*, deprecated)
    public convenience init(
        animationData: String = "",
        fileName: String = "",
        webURL: String = "",
        config: AnimationConfig,
        threads: Int? = nil
    ) {
        if webURL != "" {
            self.init(webURL: webURL, config: config, threads: threads)
        } else if animationData != "" {
            self.init(animationData: animationData, config: config, threads: threads)
        } else if fileName != "" {
            self.init(fileName: fileName, config: config, threads: threads)
        } else {
            self.init(config: config, threads: threads, task: { _ in }, errorMessage: { _ in "" })
        }
    }
    
    private convenience init(
        config: AnimationConfig,
        threads: Int? = nil,
        load: @escaping @Sendable (DotLottieAnimation) async throws -> Void,
        errorMessage: @escaping @Sendable (Error) -> String
    ) {
        self.init(config: config, threads: threads) { `self` in
            Task {
                do {
                    try await load(self)
                } catch {
                    print(errorMessage(error))
                    self.animationModel.error = true
                }
            }
        } errorMessage: {
            errorMessage($0)
        }
    }
    
    private init(
        config: AnimationConfig,
        threads: Int? = nil,
        task: (DotLottieAnimation) throws -> Void,
        errorMessage: @escaping @Sendable (Error) -> String
    ) {
        self.config = Config(autoplay: config.autoplay ?? false,
                             loopAnimation: config.loop ?? false,
                             loopCount: UInt32(config.loopCount ?? 0),
                             mode: config.mode ?? Mode.forward,
                             speed: config.speed ?? 1.0,
                             useFrameInterpolation: config.useFrameInterpolation ?? false,
                             segment: config.segments != nil ? [config.segments!.0, config.segments!.1] : [],
                             backgroundColor: 0,
                             layout: config.layout ?? createDefaultLayout(),
                             marker: config.marker ?? "",
                             themeId: config.themeId ?? "",
                             stateMachineId: config.stateMachineId ?? "",
                             animationId: config.animationId ?? "")
        
        self.player = Player(config: self.config, threads: threads)

        if (config.width != nil || config.height != nil) {
            self.sizeOverrideActive = true
        }
        
        self.animationModel.width = config.width ?? defaultWidthHeight
        self.animationModel.height = config.height ?? defaultWidthHeight
        
        do {
            try task(self)
        } catch {
            print(errorMessage(error))
            animationModel.error = true
        }
        #if !os(watchOS)
        animationModel.backgroundColor = config.backgroundColor ?? .clear
        #endif
    }
    
    public func render() -> Bool {
        player.render()
    }
    
    // MARK: Tick

    /// Advances the animation by `dt` seconds and renders if the frame changed.
    public func tick(dt: Float) -> CGImage? {
        player.tick(dt: dt)
    }

#if !os(watchOS)
    /// Advances the animation and returns the GPU-visible `MTLBuffer` the core rendered into
    /// for the current frame (Metal render path). Returns `nil` when the frame is unchanged.
    func tickMetalBuffer(dt: Float) -> (buffer: MTLBuffer, width: Int, height: Int)? {
        player.tickMetalBuffer(dt: dt)
    }

    /// Supplies the Metal device so the render buffer can be allocated GPU-visible (zero-copy).
    func setMetalDevice(_ device: MTLDevice?) {
        player.setMetalDevice(device)
    }
#endif

    /// Renders the current frame without advancing time.
    public func frameImage() -> CGImage? {
        player.tick(dt: 0)
    }
    
    // MARK: Loaders
    
    /// Loads animation from the animation data.
    /// - Parameter animationData: Animation data (.json).
    private func loadAnimation(animationData: String) throws {
        do {
            DispatchQueue.main.async {
                do {
                    self.framerate = try getAnimationFramerate(animationData: animationData)
                } catch {
                    self.framerate = 30
                }
            }
            
            try player.loadAnimationData(animationData: animationData, width: self.animationModel.width, height: self.animationModel.height)
        } catch let error {
            animationModel.error = true
            animationModel.errorMessage = error.localizedDescription
            
            throw error
        }
    }
    
    /// Passes the .lottie Data to the Core
    private func loadDotLottie(data: Data) throws {
        do {
            print("LOADING DOTLOTTIE DATA: \(self.animationModel.width), \(self.animationModel.height)")
            try player.loadDotlottieData(data: data, width: self.animationModel.width, height: self.animationModel.height)
            
            if config.stateMachineId != "" {
                _ = stateMachineStart(id: config.stateMachineId)
            }
        } catch let error {
            animationModel.error = true
            animationModel.errorMessage = error.localizedDescription
            
            throw error
        }
    }
    
    /// Loads a .lottie animation from the main bundle.
    /// - Parameters:
    ///   - animationName: File name inside the bundle to use.
    ///   - bundle: Bundle to use.
    private func loadDotLottieFromBundle(animationName: String, bundle: Bundle) throws {
        do {
            let fileData = try fetchFileFromBundle(animationName: animationName,
                                                   extensionName: "lottie",
                                                   bundle: bundle)
            try self.loadDotLottie(data: fileData)
        } catch let error {
            self.animationModel.errorMessage = error.localizedDescription
            self.animationModel.error = true
            
            throw error
        }
    }
    
    /// Loads animations (.json + .lottie) from the main bundle.
    /// - Parameters:
    ///   - animationName: Name of the animation inside the bundle.
    ///   - bundle: Bundle to use.
    private func loadAnimationFromBundle(animationName: String, bundle: Bundle) throws {
        do {
            let animationData = try fetchFileFromBundle(animationName: animationName,
                                                        extensionName: "json",
                                                        bundle: bundle)
            
            let stringData = String(decoding: animationData, as: UTF8.self)
            
            try self.loadAnimation(animationData: stringData)
        } catch {
            do {
                try loadDotLottieFromBundle(animationName: animationName, bundle: bundle)
            } catch let error {
                self.animationModel.errorMessage = error.localizedDescription
                self.animationModel.error = true
                
                throw error
            }
        }
    }
    
    /// Loads animation with the id passed as argument.
    /// - Parameter animationId: The id of the animation to play.
    public func loadAnimationById(_ animationId: String) throws {
        do {
            try player.loadAnimation(animationId: animationId, width: self.animationModel.width, height: self.animationModel.height)
        } catch let error {
            animationModel.error = true
            animationModel.errorMessage = error.localizedDescription
            
            throw error
        }
    }
    
    // MARK: Callbacks
    public func subscribe(observer: Observer) {
        self.player.subscribe(observer: observer);
    }
    
    public func unsubscribe(observer: Observer) {
        self.player.unsubscribe(observer: observer);
    }
    
    // MARK: Background color
    #if !os(watchOS)
    public func setBackgroundColor(bgColor: CIImage) {
        self.animationModel.backgroundColor = bgColor
    }

    public func backgroundColor() -> CIImage {
        return self.animationModel.backgroundColor
    }
    #endif
    
    // MARK: Playback setters / getters
    
    @discardableResult
    public func play() -> Bool {
        self.player.play()
    }
    
    /// Plays animation from specified frame
    /// - Parameter frame: Frame in range between 0 and totalFrames()
    /// - Returns: True if animation is playing
    @discardableResult
    public func play(fromFrame frame: Float) -> Bool {
        player.setFrame(no: frame)
        return player.play()
    }
    
    /// Plays animation from specified progress
    /// - Parameter progress: Progress in range between 0 and 1
    /// - Returns: True if animation is playing
    @discardableResult
    public func play(fromProgress progress: Float) -> Bool {
        guard progress > 0 && progress < 1 else {
            return false
        }
        
        setProgress(progress: progress)
        return player.play()
    }
    
    @discardableResult
    public func pause() -> Bool {
        self.player.pause()
    }
    
    /**
     Stop the animation.
     Expected behaviour:
     - If no segments and direction is 1 (forward) go to frame 0
     - If there are segments and direction is 1 go to segments.0
     
     - If there are no segments and direction is 1 (forward) go to start frame
     - If there are segments and direction is -1 (reverse) go to end frame
     */
    @discardableResult
    public func stop() -> Bool {
        player.stop()
    }
    
    public func currentProgress() -> Float {
        player.currentFrame() / player.totalFrames()
    }
    
    public func currentFrame() -> Float {
        return player.currentFrame()
    }
    
    public func totalFrames() -> Float {
        return player.totalFrames()
    }
    
    @discardableResult
    public func loop() -> Bool {
        return player.config().loopAnimation
    }
    
    public func setLoop(loop: Bool) {
        var config = player.config()
        
        config.loopAnimation = loop
        
        player.setConfig(config: config)
    }
    
    public func segments() -> (Float, Float) {
        return (player.config().segment[0], player.config().segment[1])
    }
    
    /// Set the current frame.
    /// Can return false if the frame is invalid or equal to the current frame.
    @discardableResult
    public func setFrame(frame: Float) -> Bool {
        return player.setFrame(no: frame)
    }
    
    /// Set the current progress.
    /// Can return false if the progress is invalid or equal to the current progress.
    @discardableResult
    public func setProgress(progress: Float) -> Bool {
        guard progress > 0 && progress < 1 else {
            return false
        }
        
        return player.setFrame(no: progress*totalFrames())
    }
    
    public func setFrameInterpolation(_ useFrameInterpolation: Bool) {
        var config = player.config()
        
        config.useFrameInterpolation = useFrameInterpolation
        
        player.setConfig(config: config)
    }
    
    /// Define two frames to define a segment for the player to play in-between.
    public func setSegments(segments: (Float, Float)) {
        var config = player.config()
        
        config.segment = [segments.0, segments.1]
        
        player.setConfig(config: config)
    }
    
    public func setMode(mode: Mode) {
        var config = player.config()

        config.mode = mode

        player.setConfig(config: config)
    }

    /// The current layout (fit + alignment) used to position the animation within the view.
    public func layout() -> Layout {
        return player.config().layout
    }

    /// Update how the animation is fitted and aligned within the view.
    /// Takes effect immediately on the next rendered frame.
    public func setLayout(layout: Layout) {
        var config = player.config()

        config.layout = layout

        player.setConfig(config: config)
    }

    public func isPlaying() -> Bool {
        return player.isPlaying()
    }
    
    public func isPaused() -> Bool {
        return player.isPaused()
    }
    
    public func isStopped() -> Bool {
        return player.isStopped()
    }
    
    public func autoplay() -> Bool {
        return player.config().autoplay
    }
    
    public func isLoaded() -> Bool {
        return player.isLoaded()
    }
    
    public func useFrameInterpolation() -> Bool {
        return player.config().useFrameInterpolation
    }
    
    public func isStateMachineRunning() -> Bool {
        player.isStateMachineRunning()
    }

    @discardableResult
    public func stateMachineLoad(id: String) -> Bool {
        config.stateMachineId = id
        let ret = player.stateMachineLoad(id: id)
        if ret { cachedStateMachineInputs = parseStateMachineInputs(from: getStateMachine(id)) }
        return ret
    }
    
    public func stateMachineLoadData(_ data: String) -> Bool {
        let ret = player.stateMachineLoadData(data)
        if ret { cachedStateMachineInputs = parseStateMachineInputs(from: data) }
        return ret
    }
    
    public func stateMachineStop() -> Bool {
        return player.stateMachineStop()
    }

    public func stateMachineStart(openUrlPolicy: OpenUrlPolicy = OpenUrlPolicy()) -> Bool {
        let sm = player.stateMachineStart(openUrlPolicy: openUrlPolicy)

        let _ = player.stateMachineInternalSubscribe(observer: self.internalStateMachineObserver)

        self.stateMachineListeners = stateMachineFrameworkSetup().map { $0.lowercased() }

        return sm
    }

    /// Convenience helper to load and start a specific state machine by id.
    /// It stops any running state machine, loads the requested one, and starts it.
    @discardableResult
    public func stateMachineStart(id: String, openUrlPolicy: OpenUrlPolicy = OpenUrlPolicy()) -> Bool {
        _ = stateMachineStop()
        guard stateMachineLoad(id: id) else { return false }
        return stateMachineStart(openUrlPolicy: openUrlPolicy)
    }
    
    public func stateMachinePostEvent(_ event: Event, force: Bool? = false) {
        // Extract the event name before the parenthesis
        let eventName = String(describing: event).components(separatedBy: "(").first?.lowercased() ?? String(describing: event)
        
        if (force ?? false) {
            player.stateMachinePostEvent(event: event)
        } else if (self.stateMachineListeners.contains(eventName)) {
            player.stateMachinePostEvent(event: event)
        }
    }
    
    @discardableResult
    public func setSlots(_ slots: String) -> Bool {
        player.setSlots(slots)
    }

    @discardableResult
    public func clearSlots() -> Bool {
        player.clearSlots()
    }

    @discardableResult
    public func clearSlot(slotId: String) -> Bool {
        player.clearSlot(slotId: slotId)
    }

    @discardableResult
    public func setColorSlot(slotId: String, r: Float, g: Float, b: Float) -> Bool {
        player.setColorSlot(slotId: slotId, r: r, g: g, b: b)
    }

    @discardableResult
    public func setScalarSlot(slotId: String, value: Float) -> Bool {
        player.setScalarSlot(slotId: slotId, value: value)
    }

    @discardableResult
    public func setTextSlot(slotId: String, text: String) -> Bool {
        player.setTextSlot(slotId: slotId, text: text)
    }

    @discardableResult
    public func setVectorSlot(slotId: String, x: Float, y: Float) -> Bool {
        player.setVectorSlot(slotId: slotId, x: x, y: y)
    }

    @discardableResult
    public func setPositionSlot(slotId: String, x: Float, y: Float) -> Bool {
        player.setPositionSlot(slotId: slotId, x: x, y: y)
    }

    @discardableResult
    public func setImageSlotPath(slotId: String, path: String) -> Bool {
        player.setImageSlotPath(slotId: slotId, path: path)
    }

    @discardableResult
    public func setImageSlotDataUrl(slotId: String, dataUrl: String) -> Bool {
        player.setImageSlotDataUrl(slotId: slotId, dataUrl: dataUrl)
    }

    @discardableResult
    public func setTheme(_ themeId: String) -> Bool {
        player.setTheme(themeId)
    }
    
    @discardableResult
    public func setThemeData(_ themeData: String) -> Bool {
        player.setThemeData(themeData)
    }
    
    @discardableResult
    
    public func resetTheme() -> Bool {
        player.resetTheme()
    }
    
    
    public func activeThemeId() -> String {
        player.activeThemeId()
    }
    
    public func activeAnimationId() -> String {
        player.activeAnimationId()
    }
    
    public func stateMachineFire(event: String) {
        player.stateMachineFire(event: event)
    }
    
    public func stateMachineSubscribe(_ observer: StateMachineObserver) -> Bool {
        player.stateMachineSubscribe(observer: observer)
    }
    
    public func stateMachineUnsubscribe(_ observer: StateMachineObserver) -> Bool {
        player.stateMachineUnSubscribe(oberserver: observer)
    }
    
    public func stateMachineFrameworkSetup() -> [String] {
        let flags = player.stateMachineFrameworkSetup()
        var events: [String] = []
        if flags & (1 << 0) != 0 { events.append("pointerup") }
        if flags & (1 << 1) != 0 { events.append("pointerdown") }
        if flags & (1 << 2) != 0 { events.append("pointerenter") }
        if flags & (1 << 3) != 0 { events.append("pointerexit") }
        if flags & (1 << 4) != 0 { events.append("pointermove") }
        if flags & (1 << 5) != 0 { events.append("click") }
        if flags & (1 << 6) != 0 { events.append("oncomplete") }
        if flags & (1 << 7) != 0 { events.append("onloopcomplete") }
        return events
    }
    
    public func stateMachineSetNumericInput(key: String, value: Float) -> Bool {
        player.stateMachineSetNumericInput(key: key, value: value)
    }
    
    public func stateMachineSetStringInput(key: String, value: String) -> Bool {
        player.stateMachineSetStringInput(key: key, value: value)
    }
    
    public func stateMachineSetBooleanInput(key: String, value: Bool) -> Bool {
        player.stateMachineSetBooleanInput(key: key, value: value)
    }
    
    public func stateMachineGetNumericInput(key: String) -> Float {
        player.stateMachineGetNumericInput(key: key)
    }
    
    public func stateMachineGetStringInput(key: String) -> String {
        player.stateMachineGetStringInput(key: key)
    }
    
    public func stateMachineGetBooleanInput(key: String) -> Bool {
        player.stateMachineGetBooleanInput(key: key)
    }
    
    public func stateMachineGetInputs() -> [String: String] {
        return cachedStateMachineInputs
    }

    private func parseStateMachineInputs(from json: String) -> [String: String] {
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inputs = obj["inputs"] as? [[String: Any]] else { return [:] }
        var result: [String: String] = [:]
        for input in inputs {
            if let name = input["name"] as? String, let type_ = input["type"] as? String {
                result[name] = type_
            }
        }
        return result
    }
    
    public func stateMachineCurrentState() -> String {
        player.stateMachineCurrentState()
    }
    
    public func getStateMachine(_ id: String) -> String {
        player.getStateMachine(id)
    }
    
    public func setAutoplay(autoplay: Bool) {
        var config = player.config()
        
        config.autoplay = autoplay
        
        player.setConfig(config: config)
    }
    
    public func speed() -> Float {
        return player.config().speed
    }
    
    public func setSpeed(speed: Float) {
        var config = player.config()
        
        config.speed = speed
        
        player.setConfig(config: config)
    }
    
    public func duration() -> Float {
        return player.duration()
    }
    
    public func error() -> Bool {
        return self.animationModel.error
    }
    
    public func errorMessage() -> String {
        return self.animationModel.errorMessage
    }
    
    public func mode() -> Mode {
        return player.config().mode
    }
    
    public func manifest() -> Manifest? {
        return player.manifest()
    }
    
    public func markers() -> [Marker] {
        return player.markers()
    }
    
    public func setMarker(marker: String) {
        var config = player.config()
        
        config.marker = marker
        
        player.setConfig(config: config)
    }
    
    public func resize(width: Int, height: Int) {
        self.animationModel.width = width
        self.animationModel.height = height
        
        print("Resize \(width) \(height)")
        do {
            try player.resize(width: width, height: height)
            
        } catch let error {
            self.animationModel.error = true
            self.animationModel.errorMessage = error.localizedDescription
        }
    }
    
    public func loopCount() -> Int {
        return player.loopCount()
    }
    
    // MARK: View creators
    public func view() -> DotLottieView {
        DotLottieView(dotLottie: self)
    }

#if os(iOS)
    public func view() -> DotLottieAnimationView {
            DotLottieAnimationView(dotLottieViewModel: self)
    }
#endif
}
