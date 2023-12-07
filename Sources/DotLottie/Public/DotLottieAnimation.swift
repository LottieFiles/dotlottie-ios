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

// MARK: - DotLottie

// Currently DotLottie is setup to manage a single animation and its playback settings.
// It manages the lifecycle of a renderer as well as advancing the animation and returning frames to the views.
// The playback loop is left up to the subclasses to manage leaving the implementation open for the most pratical one per platform.
// In the future this class will manage multiple animations contained inside a single .lottie.
public class DotLottieAnimation: ObservableObject, PlayerEvents {
    @Published public var playerState: PlayerState = .paused
    
    private var animationModel: AnimationModel = AnimationModel(id: "animation_0")
    
    internal var callbacks: [AnimationEvent: [() -> Void]] = [:]
    
    private var loopCounter: Int = 0
    
    private var thorvg: Thorvg
    
    private var animationData: String?
    
    private var prevState: PlayerState
    
    private var directionState: Int = 1
    
    public init(
        animationData: String = "",
        fileName: String = "",
        webURL: String = "",
        loop: Bool = false,
        autoplay: Bool = false,
        speed: Int = 1,
        mode: Mode = .forward,
        defaultActiveAnimation: Bool = false,
        width: Int = 512,
        height: Int = 512,
        segments: (Float, Float)?,
        backgroundColor: CIImage = CIImage.white) {
            thorvg = Thorvg()
            self.prevState = .paused
            self.playerState = self.animationModel.autoplay ? .playing : .paused
            
            animationModel.width = width
            animationModel.height = height
            animationModel.loop = loop
            animationModel.autoplay = autoplay
            animationModel.speed = speed
            animationModel.mode = mode
            animationModel.defaultActiveAnimation = defaultActiveAnimation
            animationModel.backgroundColor = backgroundColor
            
            // Currently refactored methods
            if webURL != "" {
                if webURL.contains(".lottie") {
                    Task {
                        await loadDotLottieFromURL(url: webURL)
                    }
                } else {
                    Task {
                        await loadAnimationFromURL(url: webURL)
                    }
                }
            } else if animationData != "" {
                do {
                    try thorvg.loadAnimation(animationData: animationData,
                                             width: animationModel.width,
                                             height: animationModel.height)
                } catch {
                    animationModel.error = true
                    callCallbacks(event: .onLoadError)
                }
            } else if fileName != "" {
                do {
                    try loadAnimationFromBundle(animationName: fileName)
                } catch {
                    animationModel.error = true
                    callCallbacks(event: .onLoadError)
                }
            }
            
            self.initAnimation(segments: segments, mode: mode)
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
        
        self.callCallbacks(event: .onLoadError)
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
                print("forward tick Going to frame \(newFrame)")
                
                // Todo: Doesnt go to first frame
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
        
        do {
            try thorvg.clear()
        }
        catch {
            print( "Clear error" )
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
        
        thorvg.draw()
    }
    
    // MARK: Loaders
    
    
    /// Loads animation from the animation data.
    /// - Parameter animationData: Animation data (.json).
    private func loadAnimation(animationData: String) {
        do {
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
    private func loadAnimation(localPath: String) {
        do {
            try thorvg.loadAnimation(path: localPath,
                                     width: UInt32(self.animationModel.width),
                                     height: UInt32(self.animationModel.height))
            
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
    
    
    /// Fetches the animation from a web URL, writes the animations and assets
    /// to disk then passes the file path to loadAnimation.
    /// - Parameter url: Web URL pointing to a .lottie file.
    /// - Returns: Path on disk to animation.
    private func loadDotLottieFromURL(url: String) async -> URL? {
        if let url = URL(string: url) {
            do {
                // Retrieve file path to where the animation was written
                let filePath = try await fetchDotLottieAndWriteToDisk(url: url)
                
                // todo change default value
                // todo move to function
                if self.animationModel.width == 512 || self.animationModel.height == 512 {
                    // Parse width and height of animation
                    do {
                        let (animWidth, animHeight) = try getAnimationWidthHeight(filePath: filePath)
                        self.animationModel.width = Int(animWidth)
                        self.animationModel.height = Int(animHeight)
                    } catch {
                        // If for some reason width and height are missing, set to defaults
                        self.animationModel.width = 512
                        self.animationModel.height = 512
                    }
                }
                
                // Pass the path of the animation to load animation, ThorVG can manage retrieving from paths.
                self.loadAnimation(localPath: filePath.path)
                
                return filePath
            } catch let error {
                print("Failed to load dotLottie. Failed with error: \(error)")
                
                self.callCallbacks(event: .onLoadError)
            }
        }
        
        print("URL: \(url) is invalid.")
        self.callCallbacks(event: .onLoadError)
        
        return nil
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
                print("Loading from bundle failed for both .json and .lottie versions of your animation: \(error)")
                
                throw error
            }
        }
    }
    
    
    /// Loads a .lottie animation from the main bundle.
    /// - Parameter animationName: File name inside the bundle to use.
    private func loadDotLottieFromBundle(animationName: String) throws {
        do {
            let fileData = try fetchFileFromBundle(animationName: animationName,
                                                   extensionName: "lottie")
            let filePath = try writeDotLottieToDisk(dotLottie: fileData)
            // todo change default value
            // todo move to function
            if self.animationModel.width == 512 || self.animationModel.height == 512 {
                // Parse width and height of animation
                do {
                    let (animWidth, animHeight) = try getAnimationWidthHeight(filePath: filePath)
                    self.animationModel.width = Int(animWidth)
                    self.animationModel.height = Int(animHeight)
                } catch {
                    // If for some reason width and height are missing, set to defaults
                    self.animationModel.width = 512
                    self.animationModel.height = 512
                }
            }

            // Pass the path of the animation to load animation, ThorVG can manage retrieving from paths.
            self.loadAnimation(localPath: filePath.path)
        } catch let error {
            print(error)
            throw error
        }
    }
    
    
    /// Loads animation (.json) from a web URL.
    /// - Parameter url: web URL pointing to an animation.
    private func loadAnimationFromURL(url: String) async {
        do {
            if let url = URL(string: url) {
                let data = try await fetchFileFromURL(url: url)
                
                let dataAsString = String(decoding: data, as: UTF8.self)
                
                if self.animationModel.width == 512 || self.animationModel.height == 512 {
                    // Parse width and height of animation
                    do {
                        let (animWidth, animHeight) = try getAnimationWidthHeight(animationData: dataAsString)
                        self.animationModel.width = Int(animWidth)
                        self.animationModel.height = Int(animHeight)
                    } catch {
                        // If for some reason width and height are missing, set to defaults
                        self.animationModel.width = 512
                        self.animationModel.height = 512
                    }
                }
                
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
            print("Error loading from URL: \(error)")
            callCallbacks(event: .onLoadError)
        }
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
        do {
            try thorvg.frame(no: frame)
        } catch let error {
            print(error)
            self.animationModel.error = true
        }
    }
    
    public func setSegments(segments: (Float32, Float32)) {
        var startFrame = segments.0
        var endFrame = segments.1
        
        if startFrame < 0 {
            startFrame = 0
        } else if startFrame > self.totalFrames() {
            startFrame = self.totalFrames()
        }
        
        if endFrame < 0 {
            endFrame = 0
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
