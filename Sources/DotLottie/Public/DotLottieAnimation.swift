//
//  DotLottieAnimation.swift
//
//
//  Created by Sam on 31/10/2023.
//

import Foundation
import CoreImage

#if canImport(SwiftUI)
import SwiftUI
#endif

protocol PlayerEvents {
    var callbacks: [AnimationEvent: [() -> Void]] { get set }
    mutating func on(event: AnimationEvent, callback: @escaping () -> Void)
}

enum LoadErrors: Error {
    case ExtractFromBundleError
}

public enum AnimationEvent {
    case onLoad
    case onLoadError
    case onPlay
    case onPause
    case onStop
    case onFrame
    case onLoop
    case onComplete
    case onFreeze
    case onUnFreeze
    case onDestroy
}

// MARK: DotLottie

public class DotLottieAnimation: ObservableObject, PlayerEvents {
    @Published public var playerState: PlayerState = .paused
    
    @Published public var framerate: Int = 30
    
    private var animationModel: AnimationModel = AnimationModel()
    
    internal var dotLottieManager: DotLottieManager = DotLottieManager()
    
    internal var callbacks: [AnimationEvent: [() -> Void]] = [:]

    private var manifestModel: ManifestModel?
    
    private var loopCounter: Int = 0
    
    private var thorvg: Player
    
    private var animationData: String?
    
    private var prevState: PlayerState
    
    private var directionState: Int = 1
    
    private var defaultWidthHeight = 512
    
    public init(
        animationData: String = "",
        fileName: String = "",
        webURL: String = "",
        playbackConfig: PlaybackConfig
    ) {
        thorvg = Player()
        self.prevState = .paused
        
        if webURL != "" {
            if webURL.contains(".lottie") {
                Task {
                    do {
                        _ = try await loadDotLottieFromURL(url: webURL)
                    } catch let error {
                        print("Failed to load dotLottie. Failed with error: \(error)")
                        animationModel.error = true
                        callCallbacks(event: .onLoadError)
                    }
                }
            } else {
                Task {
                    do {
                        try await loadAnimationFromURL(url: webURL)
                    } catch let error {
                        print("Failed to load dotLottie. Failed with error: \(error)")
                        animationModel.error = true
                        callCallbacks(event: .onLoadError)
                    }
                }
            }
        } else if animationData != "" {
            do {
                try thorvg.loadAnimation(animationData: animationData,
                                         width: animationModel.width,
                                         height: animationModel.height)
            } catch {
                print("Thorvg failed to load.")
                animationModel.error = true
                callCallbacks(event: .onLoadError)
            }
        } else if fileName != "" {
            do {
                try loadAnimationFromBundle(animationName: fileName)
            } catch let error {
                print("Loading from bundle failed for both .json and .lottie versions of your animation: \(error)")
                animationModel.error = true
                callCallbacks(event: .onLoadError)
            }
        }
        
        self.initAnimation(segments: playbackConfig.segments, mode: playbackConfig.mode)
        
        // Override manifest values loaded from loadAnimation
        animationModel.width = playbackConfig.width
        animationModel.height = playbackConfig.height
        animationModel.loop = playbackConfig.loop
        animationModel.autoplay = playbackConfig.autoplay
        animationModel.speed = playbackConfig.speed
        animationModel.mode = playbackConfig.mode
        animationModel.backgroundColor = playbackConfig.backgroundColor
    }
    
    /// Init the segments and starting frame.
    /// - Parameters:
    ///   - segments: Optional segments if passed when creating object.
    ///   - mode: Playmode.
    private func initAnimation(segments: (Float, Float)?, mode: Mode) {
        self.on(event: .onLoad) {
            DispatchQueue.main.async {
                // Initialize segments
                if let initSegments = segments {
                    self.setSegments(segments: initSegments)
                } else {
                    self.setSegments(segments: (0.0, self.totalFrames()))
                }
                
                // Initalize first frame depending on play mode
                switch mode {
                case .forward:
                    self.setFrame(frame: self.animationModel.segments?.0 ?? 0.0)
                case .reverse:
                    self.setFrame(frame: self.animationModel.segments?.1 ?? self.totalFrames())
                case .bounce:
                    self.setFrame(frame: self.animationModel.segments?.0 ?? 0.0)
                case .bounceReverse:
                    self.setFrame(frame: self.animationModel.segments?.1 ?? self.totalFrames())
                }
            }
        }
        
        // Listen for error event and set state accordingly.
        self.on(event: .onLoadError) {
            DispatchQueue.main.async {
                self.playerState = .error
            }
        }
    }
    
    /// Generates a frame image for views to render.
    /// - Returns: Optional CGImage.
    public func render() -> CGImage? {
        if let image = thorvg.render() {
            return image
        }
        
        return nil
    }
    
    // MARK: Tick functions
    
    /// Forward tick behaviour:
    /// - Use the current frame
    /// - Force in to forward playback
    /// - Play forward -> get to end frame -> jump to start frame -> repeat
    private func forwardTick() {
        let currentFrame = self.currentFrame()
        let minFrame = self.animationModel.segments?.0 ?? 0
        let totalFrames = self.animationModel.segments?.1 ?? self.totalFrames()
        var newFrame = currentFrame + 1.0
        self.directionState = 1
        
        // If there were segments set whilst animation was playing, newFrame might be out of bounds of the new segments
        // If it is out of bounds, we jump to the start frame of the segment and start from there
        if newFrame < minFrame || newFrame > totalFrames {
            newFrame = minFrame
        }
        
        // If the animation is stopped, we start from the first frame.
        if (self.prevState == .stopped) {
            newFrame = minFrame
            
            self.prevState = self.playerState
            
            self.setFrame(frame: newFrame)
            
            callCallbacks(event: .onFrame)
            return
        }
        
        if newFrame >= totalFrames {
            newFrame = minFrame
            
            // If we're not looping - Set playing to false
            if (!animationModel.loop) {
                self.setFrame(frame: newFrame)
                
                playerState = .paused
                
                callCallbacks(event: .onComplete)
                return
            } else {
                callCallbacks(event: .onLoop)
            }
        }
        
        callCallbacks(event: .onFrame)
        self.setFrame(frame: newFrame)
    }
    
    
    /// Reverse tick behaviour:
    /// - If stopped or paused -> go to end frame
    /// - Play in reverse -> get to start frame -> jump to end frame -> repeat
    /// - If already playing use the current frame
    /// - Force in to reverse playback
    /// - Play in reverse -> get to start frame -> jump to end frame -> repeat
    private func reverseTick() {
        let currentFrame = self.currentFrame()
        let minFrames = self.animationModel.segments?.0 ?? 0.0
        let totalFrames = self.animationModel.segments?.1 ?? self.totalFrames()
        var newFrame = currentFrame - 1.0
        self.directionState = -1
        
        // If there were segments set whilst animation was playing, newFrame might be out of bounds of the new segments
        // If it is out of bounds, we jump to the end frame of the segment and start from there
        if newFrame < minFrames || newFrame > totalFrames {
            newFrame = totalFrames
        }
        
        // If the animation is paused or stopped, we start from the first frame.
        if (self.prevState == .stopped) {
            newFrame = totalFrames
            
            self.prevState = self.playerState
            
            self.setFrame(frame: newFrame)
            
            callCallbacks(event: .onFrame)
            return
        }
        
        if newFrame <= minFrames {
            newFrame = totalFrames
            
            // If we're not looping - Set playing to false
            if (!animationModel.loop) {
                self.setFrame(frame: newFrame)
                
                DispatchQueue.main.async {
                    self.playerState = .paused
                }
                
                callCallbacks(event: .onComplete)
                return
            } else {
                callCallbacks(event: .onLoop)
            }
        }
        
        callCallbacks(event: .onFrame)
        self.setFrame(frame: newFrame)
    }
    
    
    /// Bounce tick behaviour:
    /// - If stopped or paused -> go to start frame
    /// - Play forward -> go to end frame -> play in reverse -> play until start frame -> repeat
    /// - If already playing use the current frame
    /// - Use current direction and bounce when either at start or end
    private func bounceTick() {
        let currentFrame = self.currentFrame()
        let minFrames = self.animationModel.segments?.0 ?? 0.0
        let totalFrames = self.animationModel.segments?.1 ?? self.totalFrames();
        var newFrame = self.directionState == 1 ? currentFrame + 1.0 : currentFrame - 1.0
        
        // If there were segments set whilst animation was playing, newFrame might be out of bounds of the new segments
        // If it is out of bounds, we jump to the start frame of the segment and start from there
        if newFrame < minFrames || newFrame > totalFrames {
            newFrame = minFrames
        }
        
        // If the animation is paused or stopped, we start from the first frame. Otherwise we keep the same direction and current frame.
        if (self.prevState == .stopped) {
            self.directionState = 1
            newFrame = minFrames
            
            self.prevState = self.playerState
            
            self.setFrame(frame: newFrame)
            
            callCallbacks(event: .onFrame)
            return
        }
        
        if newFrame <= minFrames {
            newFrame = minFrames
            self.directionState = 1
            
            // If we're not looping - Set playing to false
            if (!animationModel.loop) {
                self.setFrame(frame: newFrame)
                
                playerState = .paused
                
                callCallbacks(event: .onComplete)
                return
            } else {
                callCallbacks(event: .onLoop)
            }
        } else if newFrame >= totalFrames {
            newFrame = totalFrames
            self.directionState = -1
        }
        
        callCallbacks(event: .onFrame)
        
        self.setFrame(frame: newFrame)
    }
    
    
    /// Bounce reverse tick behaviour:
    /// - If stopped or paused -> go to the end frame
    /// - Play in reverse -> go to frame 0 -> play forward until end frame -> repeat
    /// - If already playing use the current frame
    /// - Use current direction and bounce when either at start or end
    private func bounceReverseTick() {
        let currentFrame = self.currentFrame()
        let minFrames = self.animationModel.segments?.0 ?? 0.0
        let totalFrames = self.animationModel.segments?.1 ?? self.totalFrames()
        var newFrame = self.directionState == 1 ? currentFrame + 1.0 : currentFrame - 1.0
        
        // If there were segments set whilst animation was playing, newFrame might be out of bounds of the new segments
        // If it is out of bounds, we jump to the start frame of the segment and start from there
        if newFrame < minFrames || newFrame > totalFrames {
            newFrame = totalFrames
        }
        
        // If the animation is paused or stopped, we start from the last frame. Otherwise we keep the same direction and current frame.
        if (self.prevState == .stopped) {
            self.directionState = -1
            newFrame = totalFrames
            
            self.prevState = self.playerState
            
            self.setFrame(frame: newFrame)
            
            callCallbacks(event: .onFrame)
            return
        }
        
        if newFrame <= minFrames {
            newFrame = minFrames
            self.directionState = 1
        } else if newFrame >= totalFrames {
            newFrame = totalFrames
            self.directionState = -1
            
            // If we're not looping - Set playing to false
            if (!animationModel.loop) {
                self.setFrame(frame: newFrame)
                
                playerState = .paused
                
                callCallbacks(event: .onComplete)
                return
            } else {
                callCallbacks(event: .onLoop)
            }
        }
        
        callCallbacks(event: .onFrame)
        
        self.setFrame(frame: newFrame)
    }
    
    
    /// Handles which tick function to call based on current mode.
    public func tick() {
        if (animationModel.error) {
            return
        }
        
        if (playerState == .stopped) {
            return
        }
        
        switch animationModel.mode {
        case .forward:
            self.forwardTick()
        case .reverse:
            self.reverseTick()
        case .bounce:
            self.bounceTick()
        case .bounceReverse:
            self.bounceReverseTick()
        }
    }
    
    // MARK: Loaders
    
    
    /// Loads animation from the animation data.
    /// - Parameter animationData: Animation data (.json).
    private func loadAnimation(animationData: String) {
        do {
            self.initWidthHeight(animationData: animationData, animationFilePath: nil)
            
            do {
                self.framerate = try getAnimationFramerate(animationData: animationData)
            } catch {
                self.framerate = 30
            }
            
            try thorvg.loadAnimation(animationData: animationData, width: self.animationModel.width, height: self.animationModel.height)
            
            // Store the current loaded data for optional retrieval
            self.animationData = animationData
            
            // Autoplay the animation if needed
            DispatchQueue.main.async {
                self.prevState = self.playerState
                self.playerState = self.animationModel.autoplay ? .playing : .paused
            }
        } catch {
            animationModel.error = true
            
            self.prevState = self.playerState
            self.playerState = .paused
            
            callCallbacks(event: .onLoadError)
        }
        
        // Fire load event
        callCallbacks(event: .onLoad)
    }
    
    
    /// Loads an animation (.json) from a local file path on disk.
    /// - Parameter localPath: Path on disk to animation data.
    private func loadAnimation(localPath: URL) {
        do {
            self.initWidthHeight(animationData: nil, animationFilePath: localPath)
            
            DispatchQueue.main.async {
                do {
                    self.framerate = try getAnimationFramerate(filePath: localPath)
                } catch {
                    self.framerate = 30
                }
            }
            
            try thorvg.loadAnimationFromPath(animationPath: localPath.path,
                                             width: (self.animationModel.width),
                                             height: (self.animationModel.height))
            
            // Autoplay the animation if needed
            DispatchQueue.main.async {
                self.prevState = self.playerState
                self.playerState = self.animationModel.autoplay ? .playing : .paused
            }
            
        } catch let error {
            DispatchQueue.main.async {
                self.animationModel.error = true
                
                self.prevState = self.playerState
                self.playerState = .paused
            }
            
            print("Error loading from thorvg: \(error)")
            
            callCallbacks(event: .onLoadError)
        }
        
        // Fire load event
        callCallbacks(event: .onLoad)
    }
    
    /// Loads the settings defined inside the manifest file of the .lottie.
    /// - Parameter manifest: Manifest model to use.
    private func loadManifestSettings(manifest: ManifestModel) {
        if let ap = manifest.animations.first?.autoplay {
            self.animationModel.autoplay = ap
        }
        
        if let bg = manifest.animations.first?.backgroundColor {
            self.animationModel.backgroundColor = CIImage(color: CIColor(string: bg))
        }
        
        if let dir = manifest.animations.first?.direction {
            self.directionState = dir
        }
        
        if let loop = manifest.animations.first?.loop {
            self.animationModel.loop = loop
        }
        
        if let playMode = manifest.animations.first?.playMode {
            switch playMode {
            case "bounce":
                self.animationModel.mode = .bounce
            case "bounceReverse":
                self.animationModel.mode = .bounceReverse
            case "reverse":
                self.animationModel.mode = .reverse
            case "forward":
                self.animationModel.mode = .forward
            default:
                self.animationModel.mode = .forward
            }
        }
        
        if let speed = manifest.animations.first?.speed {
            self.animationModel.speed = speed
        }
    }
    
    
    /// Load the next animation of the dotLottie.
    public func nextAnimation(playbackConfig: PlaybackConfig?) {
        do {
            let m = try self.dotLottieManager.nextAnimation()
            
            loadFromId(animationId: m.id, playbackConfig: playbackConfig)
        } catch {
            self.animationModel.error = true
            self.animationModel.errorMessage = "prevAnimation: Error loading next animation."
        }
    }
    
    /// Load the previous animation of the dotLottie.
    public func prevAnimation(playbackConfig: PlaybackConfig?) {
        do {
            let m = try self.dotLottieManager.prevAnimation()
            
            loadFromId(animationId: m.id, playbackConfig: playbackConfig)
        } catch {
            self.animationModel.error = true
            self.animationModel.errorMessage = "prevAnimation: Error loading previous animation."
        }
    }
    
    /// Load an animation via it's id.
    /// - Parameter animationId: Id of the animation.
    public func loadFromId(animationId: String, playbackConfig: PlaybackConfig?) {
        self.stop()
        
        self.thorvg = Player()
        
        do {
            let path = try self.dotLottieManager.getAnimationPath(animationId)
            
            self.loadAnimation(localPath: path)
        } catch {
            self.animationModel.error = true
            self.animationModel.errorMessage = "prevAnimation: Error loading \(animationId)"
        }
    }
    
    /// Loads a .lottie animation from the main bundle.
    /// - Parameter animationName: File name inside the bundle to use.
    private func loadDotLottieFromBundle(animationName: String) throws {
        do {
            // Initialize the manager with the animation from the main asset bundle.
            try dotLottieManager.initFromBundle(assetName: animationName)
            
            let currId = self.dotLottieManager.getCurrentAnimationId()
            
            // Get the path on disk to the animation
            let filePath = try self.dotLottieManager.getAnimationPath(currId)
            
            self.manifestModel = self.dotLottieManager.manifest
            
            // Load the manifest settings in to the AnimationModel
            if let m = self.manifestModel {
                self.loadManifestSettings(manifest: m)
            }
            
            // Pass the path of the animation to load animation, ThorVG can manage retrieving from paths.
            self.loadAnimation(localPath: filePath)
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
                try await self.dotLottieManager.initFromWebUrl(url: url)
                
                let currId = self.dotLottieManager.getCurrentAnimationId()
                
                let filePath = try self.dotLottieManager.getAnimationPath(currId)
                
                self.manifestModel = self.dotLottieManager.manifest
                
                self.initWidthHeight(animationData: nil, animationFilePath: filePath)
                
                // Load the manifest settings in to the AnimationModel
                if let m = self.manifestModel {
                    self.loadManifestSettings(manifest: m)
                }
                // Pass the path of the animation to load animation, ThorVG can manage retrieving from paths.
                self.loadAnimation(localPath: filePath)
            } catch let error {
                self.callCallbacks(event: .onLoadError)
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
            
            self.loadAnimation(animationData: stringData)
        } catch {
            do {
                try loadDotLottieFromBundle(animationName: animationName)
            } catch let error {
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
                    self.loadAnimation(animationData: dataAsString)
                } else {
                    print("Failed to convert data to String.")
                    
                    self.callCallbacks(event: .onLoadError)
                }
            } else {
                print("Invalid URL")
                
                callCallbacks(event: .onLoadError)
            }
        } catch let error {
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
        //        }
    }
    
    // MARK: Callbacks
    
    public func on(event: AnimationEvent, callback: @escaping () -> Void) {
        if callbacks[event] == nil {
            callbacks[event] = []
        }
        callbacks[event]?.append(callback)
    }
    
    public func callCallbacks(event: AnimationEvent) {
        if let eventCallbacks = callbacks[event] {
            if event == .onLoop {
                loopCounter += 1
            }
            for callback in eventCallbacks {
                callback()
            }
        }
    }
    
    public func setBackgroundColor(bgColor: CIImage) {
        self.animationModel.backgroundColor = bgColor
    }
    
    public func backgroundColor() -> CIImage {
        return self.animationModel.backgroundColor
    }
    
    // MARK: Playback setters / getters
    
    public func play() {
        DispatchQueue.main.async {
            self.prevState = self.playerState
            self.playerState = .playing
            
            self.callCallbacks(event: .onPlay)
        }
    }
    
    public func pause() {
        DispatchQueue.main.async {
            self.prevState = self.playerState
            self.playerState = .paused
            
            self.callCallbacks(event: .onPause)
        }
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
        if mode() == .forward || mode() == .bounce {
            self.setFrame(frame: self.animationModel.segments?.0 ?? 0.0)
        } else if mode() == .reverse || mode() == .bounceReverse {
            self.setFrame(frame: animationModel.segments?.1 ?? self.totalFrames())
        }
        
        DispatchQueue.main.async {
            self.prevState = self.playerState
            self.playerState = .stopped
        }
        callCallbacks(event: .onStop)
    }
    
    public func freeze() {
        DispatchQueue.main.async {
            self.prevState = self.playerState
            
            self.playerState = .frozen
        }
        callCallbacks(event: .onFreeze)
    }
    
    public func unfreeze() {
        DispatchQueue.main.async {
            self.playerState = self.prevState
        }
        callCallbacks(event: .onUnFreeze)
    }
    
    public func currentFrame() -> Float32 {
        return thorvg.currentFrame()
    }
    
    public func totalFrames() -> Float32 {
        return thorvg.totalFrames() - 1
    }
    
    public func loop() -> Bool {
        return animationModel.loop
    }
    
    public func setLoop(loop: Bool) {
        animationModel.loop = loop
    }
    
    public func segments() -> (Float32, Float32) {
        return animationModel.segments ?? (0, self.totalFrames())
    }
    
    public func setFrame(frame: Float32) {
        thorvg.frame(no: frame)
    }
    
    public func setSegments(segments: (Float32, Float32)) {
        var startFrame = segments.0
        var endFrame = segments.1
        
        if startFrame < 0 {
            startFrame = 0
        } else if startFrame > self.totalFrames() {
            startFrame = 0
        }
        
        if endFrame < 0 {
            endFrame = self.totalFrames()
        } else if endFrame > self.totalFrames() {
            endFrame = self.totalFrames()
        }
        animationModel.segments = (startFrame, endFrame)
    }
    
    public func setMode(mode: Mode) {
        animationModel.mode = mode
    }
    
    public func direction() -> Int {
        return self.directionState
    }
    
    public func isPlaying() -> Bool {
        return playerState == .playing
    }
    
    public func isPaused() -> Bool {
        return playerState == .paused
    }
    
    public func isStopped() -> Bool {
        return playerState == .stopped
    }
    
    public func isFrozen () -> Bool {
        return playerState == .frozen
    }
    
    public func autoplay() -> Bool {
        return animationModel.autoplay
    }
    
    public func setAutoplay(autoplay: Bool) {
        animationModel.autoplay = autoplay
    }
    
    public func speed() -> Int {
        return animationModel.speed
    }
    
    public func setSpeed(speed: Int) {
        animationModel.speed = speed
    }
    
    public func duration() -> Float32 {
        return thorvg.duration()
    }
    
    public func mode() -> Mode {
        return animationModel.mode
    }
    
    public func loopCount() -> Int {
        return self.loopCounter
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
