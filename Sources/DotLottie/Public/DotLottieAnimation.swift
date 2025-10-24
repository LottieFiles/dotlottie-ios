//
//  DotLottieAnimation.swift
//
//
//  Created by Sam on 31/10/2023.
//

import Foundation
import CoreImage

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
    
    private var currFrame = 0;

    /// Load directly from a String (.json).
    public convenience init(
        animationData: String,
        config: AnimationConfig,
        threads: Int? = nil
    ) {
        self.init(config: config, threads: threads) {
            try $0.player.loadAnimationData(animationData: animationData,
                                            width: $0.animationModel.width,
                                            height: $0.animationModel.height)
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
        self.init(config: config, threads: threads) {
            if webURL.contains(".lottie") {
                try await $0.loadDotLottieFromURL(url: webURL)
            } else {
                try await $0.loadAnimationFromURL(url: webURL)
            }
        } errorMessage: { error in
            "Failed to load dotLottie. Failed with error: \(error)"
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
        animationModel.backgroundColor = config.backgroundColor ?? .clear
    }
    
    public func render() -> Bool {
        player.render()
    }
    
    // MARK: Tick
    
    /// Requests a frame and renders it if necessary
    public func tick() -> CGImage? {
        if let image = player.tick() {
            return image
        }
        
        return nil
    }
    
    /// Generates frame image
    public func frameImage() -> CGImage? {
        player.tick()
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
            try player.loadDotlottieData(data: data, width: self.animationModel.width, height: self.animationModel.height)
            
            if config.stateMachineId != "" {
                let _ = player.stateMachineInternalSubscribe(observer: self.internalStateMachineObserver)
                
                self.stateMachineListeners = stateMachineFrameworkSetup().map { $0.lowercased() }
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
    
    /// Fetches the animation from a web URL, writes the animations and assets
    /// to disk then passes the file path to loadAnimation.
    /// - Parameter url: Web URL pointing to a .lottie file.
    /// - Returns: Path on disk to animation.
    private func loadDotLottieFromURL(url: String) async throws {
        if let url = URL(string: url) {
            do {
                let data = try await fetchFileFromURL(url: url)
                
                try self.loadDotLottie(data: data)
            } catch let error {
                self.animationModel.errorMessage = error.localizedDescription
                self.animationModel.error = true
                
                throw error
            }
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
    
    /// Loads animation (.json) from a web URL.
    /// - Parameter url: web URL pointing to an animation.
    private func loadAnimationFromURL(url: String) async throws {
        do {
            if let url = URL(string: url) {
                let data = try await fetchFileFromURL(url: url)
                
                let dataAsString = String(decoding: data, as: UTF8.self)
                
                if dataAsString != "" {
                    try self.loadAnimation(animationData: dataAsString)
                } else {
                    throw AnimationLoadErrors.convertToStringError
                }
            } else {
                throw NetworkingErrors.invalidURL
            }
        } catch let error {
            self.animationModel.errorMessage = error.localizedDescription
            self.animationModel.error = true
            
            throw error
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
    
    private func initWidthHeight(animationData: String?, animationFilePath: URL?) {
        // Parse width and height of animation
        do {
            if let aData = animationData {
                let (animWidth, animHeight) = try getAnimationWidthHeight(animationData: aData)
                self.animationModel.width = Int(animWidth)
                self.animationModel.height = Int(animHeight)
            } else if let aFP = animationFilePath {
                let (animWidth, animHeight) = try getAnimationWidthHeight(filePath: aFP)
                self.animationModel.width = Int(animWidth)
                self.animationModel.height = Int(animHeight)
            }
        } catch {
            // If for some reason width and height are missing, set to defaults
            self.animationModel.width = self.defaultWidthHeight
            self.animationModel.height = self.defaultWidthHeight
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
    public func setBackgroundColor(bgColor: CIImage) {
        self.animationModel.backgroundColor = bgColor
    }
    
    public func backgroundColor() -> CIImage {
        return self.animationModel.backgroundColor
    }
    
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
    
    public func getLayerBounds(layerName: String) -> [Float] {
        player.getLayerBounds(layerName: layerName)
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
    
    @discardableResult
    public func stateMachineLoad(id: String) -> Bool {
        player.stateMachineLoad(id: id)
    }
    
    public func stateMachineLoadData(_ data: String) -> Bool {
        let ret = player.stateMachineLoadData(data)
        
        return ret
    }
    
    public func stateMachineStop() -> Bool {
        let stop = player.stateMachineStop()
        
        let _ = player.stateMachineInternalSubscribe(observer: self.internalStateMachineObserver)
        
        return stop
    }
    
    public func stateMachineStart(openUrlPolicy: OpenUrlPolicy = OpenUrlPolicy(requireUserInteraction: true, whitelist: [])) -> Bool {
        let sm = player.stateMachineStart(openUrlPolicy: openUrlPolicy)
        
        let _ = player.stateMachineInternalSubscribe(observer: self.internalStateMachineObserver)
        
        self.stateMachineListeners = stateMachineFrameworkSetup().map { $0.lowercased() }
        
        return sm
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
    
    public func setSlots(_ slots: String) -> Bool {
        player.setSlots(slots)
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
    
    public func stateMachineUnSubscribe(observer: StateMachineObserver) -> Bool {
        player.stateMachineUnSubscribe(oberserver: observer)
    }
    
    public func stateMachineFrameworkSetup() -> [String] {
        player.stateMachineFrameworkSetup()
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
        let stateArray = player.stateMachineGetInputs()
        var stateDict: [String: String] = [:]
        
        // Iterate through array in pairs (key, value)
        for i in stride(from: 0, to: stateArray.count, by: 2) {
            let key = stateArray[i]
            let type = stateArray[i + 1]
            stateDict[key] = type
        }
        
        return stateDict
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
