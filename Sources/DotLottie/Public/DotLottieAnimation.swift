//
//  DotLottieAnimation.swift
//
//
//  Created by Sam on 31/10/2023.
//

import Foundation
import CoreImage
import UIKit

private class OpenUrlObserver: StateMachineObserver {
    func onBooleanInputValueChange(inputName: String, oldValue: Bool, newValue: Bool) {
    }
    
    func onCustomEvent(message: String) {
        if message.hasPrefix("OpenUrl: ") {
            let url = message.replacingOccurrences(of: "OpenUrl: ", with: "")
            
            if let urlObject = URL(string: url),
               UIApplication.shared.canOpenURL(urlObject) {
                UIApplication.shared.open(urlObject, options: [:], completionHandler: nil)
            }
        }
    }
    
    func onError(message: String) {
    }
    
    func onNumericInputValueChange(inputName: String, oldValue: Float, newValue: Float) {
    }
    
    func onStart() {
    }
    
    func onStateEntered(enteringState: String) {
    }
    
    func onStateExit(leavingState: String) {
    }
    
    func onStop() {
    }
    
    func onStringInputValueChange(inputName: String, oldValue: String, newValue: String) {
    }
    
    func onTransition(previousState: String, newState: String) {
    }
    
    func onInputFired(inputName: String) {
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
    
#if os(iOS)
    internal var dotLottieAnimationView: DotLottieAnimationView?
#endif
    
    internal var dotLottieView: DotLottieView?
    
    internal var stateMachineListeners: [String] = []
    
    private var stateMachineUrlListener = OpenUrlObserver()
    
    private var currFrame = 0;
    
    /// Load directly from a String (.json).
    public convenience init(
        animationData: String,
        config: AnimationConfig
    ) {
        self.init(config: config) {
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
        config: AnimationConfig
    ) {
        self.init(config: config) {
            try $0.loadAnimationFromBundle(animationName: fileName, bundle: bundle)
        } errorMessage: { error in
            "Loading from bundle failed for both .json and .lottie versions of your animation: \(error)"
        }
    }
    
    /// Load an animation (.lottie / .json) from the web.
    public convenience init(
        webURL: String,
        config: AnimationConfig
    ) {
        self.init(config: config) {
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
        config: AnimationConfig
    ) {
        self.init(config: config) {
            try $0.loadDotLottie(data: dotLottieData)
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
        config: AnimationConfig
    ) {
        if webURL != "" {
            self.init(webURL: webURL, config: config)
        } else if animationData != "" {
            self.init(animationData: animationData, config: config)
        } else if fileName != "" {
            self.init(fileName: fileName, config: config)
        } else {
            self.init(config: config, task: { _ in }, errorMessage: { _ in "" })
        }
    }
    
    private convenience init(
        config: AnimationConfig,
        load: @escaping @Sendable (DotLottieAnimation) async throws -> Void,
        errorMessage: @escaping @Sendable (Error) -> String
    ) {
        self.init(config: config) { `self` in
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
        task: (DotLottieAnimation) throws -> Void,
        errorMessage: @escaping @Sendable (Error) -> String
    ) {
        self.config = Config(autoplay: config.autoplay ?? false,
                             loopAnimation: config.loop ?? false,
                             mode: config.mode ?? Mode.forward,
                             speed: config.speed ?? 1.0,
                             useFrameInterpolation: config.useFrameInterpolation ?? false,
                             segment: config.segments != nil ? [config.segments!.0, config.segments!.1] : [],
                             backgroundColor: 0,
                             layout: config.layout ?? createDefaultLayout(),
                             marker: config.marker ?? "",
                             themeId: config.themeId ?? "",
                             stateMachineId: config.stateMachineId ?? "")
        self.player = Player(config: self.config)
        
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

//        let nextFrame = player.requestFrame()
//        
//        if (nextFrame) {
//            if let image = player.render() {
//                return image
//            }
//        }
        
        return nil
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
                let _ = player.stateMachineFrameworkSubscribe(observer: self.stateMachineUrlListener)
                
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
    
    public func play() -> Bool {
        self.player.play()
    }
    
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
    public func stop() -> Bool {
        player.stop()
    }
    
    public func currentFrame() -> Float {
        return player.currentFrame()
    }
    
    public func totalFrames() -> Float {
        return player.totalFrames()
    }
    
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
    
    public func setPlayerState(_ state: PlayerState) {
        player.setPlayerState(state: state)
    }
    
    public func getLayerBounds(layerName: String) -> [Float] {
        player.getLayerBounds(layerName: layerName)
    }
    
    /// Set the current frame.
    /// Can return false if the frame is invalid or equal to the current frame.
    public func setFrame(frame: Float) -> Bool {
        return player.setFrame(no: frame)
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
    
    public func stateMachineLoad(id: String) -> Bool {
        player.stateMachineLoad(id: id)
    }
    
    public func stateMachineLoadData(_ data: String) -> Bool {
        let ret = player.stateMachineLoadData(data)
        
        return ret
    }
    
    public func stateMachineStop() -> Bool {
        let stop = player.stateMachineStop()
        
        let _ = player.stateMachineFrameworkUnsubscribe(observer: self.stateMachineUrlListener)
        
        return stop
    }
    
    public func stateMachineStart(openUrl: OpenUrl = OpenUrl(mode: .interaction, whitelist: [])) -> Bool {
        let sm = player.stateMachineStart(openUrl: openUrl)
        
        let _ = player.stateMachineFrameworkSubscribe(observer: self.stateMachineUrlListener)
        
        self.stateMachineListeners = stateMachineFrameworkSetup().map { $0.lowercased() }
        
        return sm
    }
    
    public func stateMachinePostEvent(_ event: Event, force: Bool? = false) -> Int {
        var ret: Int32 = 1
        // Extract the event name before the parenthesis
        let eventName = String(describing: event).components(separatedBy: "(").first?.lowercased() ?? String(describing: event)
        
        if (force ?? false) {
            ret = player.stateMachinePostEvent(event: event)
        } else if (self.stateMachineListeners.contains(eventName)) {
            ret = player.stateMachinePostEvent(event: event)
        }
        
        return Int(ret)
    }
    
    public func setSlots(_ slots: String) -> Bool {
        player.setSlots(slots)
    }
    
    public func setTheme(_ themeId: String) -> Bool {
        player.setTheme(themeId)
    }
    
    public func setThemeData(_ themeData: String) -> Bool {
        player.setThemeData(themeData)
    }
    
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
    
    public func stateMachineCurrentState() -> String {
        player.stateMachineCurrentState()
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
        if let prevDotLottieView = dotLottieView {
            return prevDotLottieView
        } else {
            let view: DotLottieView = DotLottieView(dotLottie: self)
            
            self.dotLottieView = view
            
            return view
        }
    }
    
#if os(iOS)
    public func view() -> DotLottieAnimationView {
        if let prevAnimationView = dotLottieAnimationView {
            return prevAnimationView
        } else {
            let view: DotLottieAnimationView = DotLottieAnimationView(dotLottieViewModel: self)
            
            self.dotLottieAnimationView = view
            
            return view
        }
    }
#endif
}
