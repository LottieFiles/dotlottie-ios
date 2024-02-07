//
//  DotLottieAnimation.swift
//
//
//  Created by Sam on 31/10/2023.
//

import Foundation
import CoreImage

// MARK: DotLottieAnimation
public class DotLottieAnimation: ObservableObject {
    @Published public var framerate: Int = 30
    
    @Published private(set) var player: Player
    
    public var sizeOverrideActive = false
    
    private var animationModel: AnimationModel = AnimationModel()
        
    private var defaultWidthHeight = 512
    
    internal var config: Config
    
    public init(
        animationData: String = "",
        fileName: String = "",
        webURL: String = "",
        config: AnimationConfig
    ) {
        self.config = Config(autoplay: config.autoplay ?? false,
                             loopAnimation: config.loop ?? false,
                             mode: config.mode ?? Mode.forward,
                             speed: config.speed ?? 1.0,
                             useFrameInterpolation: config.useFrameInterpolation ?? false,
                             segments: config.segments != nil ? [config.segments!.0, config.segments!.1] : [],
                             backgroundColor: 0)
        
        self.player = Player(config: self.config)
        
        if (config.width != nil || config.height != nil) {
            self.sizeOverrideActive = true
        }

        self.animationModel.width = config.width ?? defaultWidthHeight
        self.animationModel.height = config.height ?? defaultWidthHeight
        
        if webURL != "" {
            if webURL.contains(".lottie") {
                Task {
                    do {
                        try await loadDotLottieFromURL(url: webURL)
                    } catch let error {
                        print("Failed to load dotLottie. Failed with error: \(error)")
                        animationModel.error = true
                    }
                }
            } else {
                Task {
                    do {
                        try await loadAnimationFromURL(url: webURL)
                    } catch let error {
                        print("Failed to load dotLottie. Failed with error: \(error)")
                        animationModel.error = true
                    }
                }
            }
        } else if animationData != "" {
            do {
                try player.loadAnimationData(animationData: animationData,
                                             width: animationModel.width,
                                             height: animationModel.height)
            } catch {
                print("player failed to load.")
                animationModel.error = true
            }
        } else if fileName != "" {
            do {
                try loadAnimationFromBundle(animationName: fileName)
            } catch let error {
                print("Loading from bundle failed for both .json and .lottie versions of your animation: \(error)")
                animationModel.error = true
            }
        }
        
        animationModel.backgroundColor = config.backgroundColor ?? .clear
    }
    
    // MARK: Tick
    
    /// Requests a frame and renders it if necessary
    public func tick() -> CGImage? {
        let nextFrame = player.requestFrame()
        
        if (nextFrame || self.currentFrame() == 0.0) {
            if let image = player.render() {
                return image
            }
        }
        
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
            try player.loadDotlottieData(data: data)
            
        } catch let error {
            animationModel.error = true
            animationModel.errorMessage = error.localizedDescription
            
            throw error
        }
    }
    
    /// Loads a .lottie animation from the main bundle.
    /// - Parameter animationName: File name inside the bundle to use.
    private func loadDotLottieFromBundle(animationName: String) throws {
        do {
            let fileData = try fetchFileFromBundle(animationName: animationName,
                                                   extensionName: "lottie")
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
    /// - Parameter animationName: Name of the animation inside the bundle.
    private func loadAnimationFromBundle(animationName: String) throws {
        do {
            let animationData = try fetchFileFromBundle(animationName: animationName,
                                                        extensionName: "json")
            
            let stringData = String(decoding: animationData, as: UTF8.self)
            
            try self.loadAnimation(animationData: stringData)
        } catch {
            do {
                try loadDotLottieFromBundle(animationName: animationName)
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
    /// - Parameter animationData: Animation data (.json).
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
    
    public func play() {
        self.player.play()
    }
    
    public func pause() {
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
    public func stop() {
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
        return (player.config().segments[0], player.config().segments[1])
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
        
        config.segments = [segments.0, segments.1]
        
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
    
    public func errorMessage() -> String {
        return self.animationModel.errorMessage
    }
    
    public func mode() -> Mode {
        return player.config().mode
    }
    
    public func manifest() -> Manifest? {
        return player.manifest()
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
        let view: DotLottieView = DotLottieView(dotLottie: self)
        
        return view
    }
    
#if os(iOS)
    public func view() -> DotLottieAnimationView {
        let view: DotLottieAnimationView = DotLottieAnimationView(dotLottieViewModel: self)
        
        return view
    }
#endif
}
