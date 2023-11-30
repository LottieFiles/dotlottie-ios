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

    private var prevState: PlayerState?
    
    private var direction: Int = 1
    
#if os(iOS)
    private var bgColor: UIColor?
#elseif os(macOS)
    private var bgColor: NSColor?
#endif
    
    public init(
        animationData: String = "",
        fileName: String = "",
        webURL: String = "",
        loop: Bool = false,
        autoplay: Bool = false,
        speed: Int = 1,
        mode: Mode = .forward,
        defaultActiveAnimation: Bool = false,
        width: UInt32 = 512,
        height: UInt32 = 512,
        segments: (Float32, Float32)?) {
            thorvg = Thorvg()
            
            self.setBackgroundColor(bgColor: .orange)
            
            animationModel.width = animationModel.width
            animationModel.height = animationModel.height
            animationModel.loop = loop
            animationModel.autoplay = autoplay
            animationModel.speed = speed
            animationModel.mode = mode
            animationModel.defaultActiveAnimation = defaultActiveAnimation
            
            if animationData != "" {
                do {
                    try thorvg.loadAnimation(animationData: animationData, width: width, height: height)
                } catch {
                    animationModel.error = true
                    
                    callCallbacks(event: .onLoadError)
                }
            } else if webURL != "" {
                if webURL.contains(".lottie") {
                    fetchAndPlayAnimationFromDotLottie(url: webURL)
                } else {
                    loadAnimation(webURL: webURL, width: width, height: height)
                }
            } else if fileName != "" {
                if fileName.contains(".lottie") {
                    // Todo
                } else {
                    loadAnimation(fileName: fileName, width: width, height: height)
                }
            }
            
            self.on(event: .onLoad) {
                // Safely set the segments
                if let initSegments = segments {
                    self.setSegments(segments: initSegments)
                } else {
                    self.setSegments(segments: (0.0, self.totalFrames()))
                }
                
                self.prevState = self.playerState
                self.playerState = self.animationModel.autoplay ? .playing : .paused
            }
        }
    
    // Todo: Manage swapping out animation at runtime
    public func loadAnimation(animationData: String, width: UInt32?, height: UInt32?) {
        do {
            try thorvg.loadAnimation(animationData: animationData, width: width ?? self.animationModel.width, height: height ?? self.animationModel.height)
            
            // Store the current loaded data for optional retrieval
            self.animationData = animationData
            
            // Go to the last frame if we're playing backwards
            if (animationModel.mode == .reverse) {
                thorvg.frame(no: self.totalFrames() - 1)
            }
            
            DispatchQueue.main.async{
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
    
    public func loadAnimation(path: String, width: UInt32?, height: UInt32?) {
        do {
            try thorvg.loadAnimation(path: path, width: width ?? self.animationModel.width, height: height ?? self.animationModel.height)
            
            // Go to the last frame if we're playing backwards
            if (animationModel.mode == .reverse) {
                thorvg.frame(no: self.totalFrames() - 1)
            }
            
            DispatchQueue.main.async{
                self.prevState = self.playerState
                self.playerState = self.animationModel.autoplay ? PlayerState.playing : PlayerState.paused
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
    
    
    public func loadAnimation(webURL: String, width: UInt32?, height: UInt32?) {
        self.animationModel.width = width ?? self.animationModel.width
        self.animationModel.height = height ?? self.animationModel.height
        
        fetchAndPlayAnimationFromURL(url: webURL)
    }
    
    public func loadAnimation(fileName: String, width: UInt32?, height: UInt32?) {
        self.animationModel.width = width ?? self.animationModel.width
        self.animationModel.height = height ?? self.animationModel.height
        
        fetchAndPlayAnimationFromBundle(url: fileName)
    }
    
    // Give the view an image to render
    public func render() -> CGImage? {
        if let image = thorvg.render() {
            return image
        }
        
        self.callCallbacks(event: .onLoadError)
        return nil
    }
    
    private func forwardTick() {
        let currentFrame = self.currentFrame()
        let minFrame = self.animationModel.segments?.0 ?? 0
        let totalFrames = self.animationModel.segments?.1 ?? self.totalFrames() - 1.0
        var newFrame = currentFrame + 1.0

        if newFrame >= totalFrames {
            newFrame = minFrame
            
            // If we're not looping - Set playing to false
            if (!animationModel.loop) {
                thorvg.frame(no: newFrame)
                
                playerState = .paused

                callCallbacks(event: .onComplete)
                return
            } else {
                callCallbacks(event: .onLoop)
            }
        }
        
        callCallbacks(event: .onFrame)
        thorvg.frame(no: newFrame)
    }
    
    private func reverseTick() {
        let currentFrame = self.currentFrame()
        let minFrames = self.animationModel.segments?.0 ?? 0.0
        let totalFrames = self.animationModel.segments?.1 ?? self.totalFrames() - 1.0
        var newFrame = currentFrame - 1.0

        // If the animation is paused or stopped, we start from the first frame. Otherwise we keep the same direction and current frame.
        if (self.prevState == .paused || self.prevState == .stopped) {
            self.direction = -1
            newFrame = totalFrames
            
            self.prevState = self.playerState
            
            thorvg.frame(no: newFrame)
            
            callCallbacks(event: .onFrame)
            return
        }
        
        if newFrame <= minFrames {
            newFrame = totalFrames
            
            // If we're not looping - Set playing to false
            if (!animationModel.loop) {
                thorvg.frame(no: newFrame)

                playerState = .paused
                
                callCallbacks(event: .onComplete)
                return
            } else {
                callCallbacks(event: .onLoop)
            }
        }
        
        callCallbacks(event: .onFrame)
        thorvg.frame(no: newFrame)
    }
    
    private func bounceTick() {
        let currentFrame = self.currentFrame()
        let minFrames = self.animationModel.segments?.0 ?? 0.0
        let totalFrames = self.animationModel.segments?.1 ?? self.totalFrames() - 1.0;
        var newFrame = direction == 1 ? currentFrame + 1.0 : currentFrame - 1.0

        // If the animation is paused or stopped, we start from the first frame. Otherwise we keep the same direction and current frame.
        if (self.prevState == .paused || self.prevState == .stopped) {
            self.direction = 1
            newFrame = minFrames
            
            self.prevState = self.playerState
            
            thorvg.frame(no: newFrame)
            
            callCallbacks(event: .onFrame)
            return       
        }

        if newFrame <= minFrames {
            newFrame = minFrames
            self.direction = 1

            // If we're not looping - Set playing to false
            if (!animationModel.loop) {
                thorvg.frame(no: newFrame)

                playerState = .paused

                callCallbacks(event: .onComplete)
                return
            } else {
                callCallbacks(event: .onLoop)
            }
        } else if newFrame >= totalFrames {
            newFrame = totalFrames
            self.direction = -1
        }
        
        callCallbacks(event: .onFrame)

        thorvg.frame(no: newFrame)
    }
    
    private func bounceReverseTick() {
        let currentFrame = self.currentFrame()
        let minFrames = self.animationModel.segments?.0 ?? 0.0
        let totalFrames = self.animationModel.segments?.1 ?? self.totalFrames() - 1.0
        var newFrame = direction == 1 ? currentFrame + 1.0 : currentFrame - 1.0

        // If the animation is paused or stopped, we start from the last frame. Otherwise we keep the same direction and current frame.
        if (self.prevState == .paused || self.prevState == .stopped) {
            self.direction = -1
            newFrame = totalFrames
            
            self.prevState = self.playerState
            
            thorvg.frame(no: newFrame)
            
            callCallbacks(event: .onFrame)
            return
        }
        
        if newFrame <= minFrames {
            newFrame = minFrames
            self.direction = 1
        } else if newFrame >= totalFrames {
            newFrame = totalFrames
            self.direction = -1
            
            // If we're not looping - Set playing to false
            if (!animationModel.loop) {
                thorvg.frame(no: newFrame)

                playerState = .paused

                callCallbacks(event: .onComplete)
                return
            } else {
                callCallbacks(event: .onLoop)
            }
        }
        
        callCallbacks(event: .onFrame)

        thorvg.frame(no: newFrame)
    }
    
    public func tick() {
        if (animationModel.error) {
            return
        }
        
        if (playerState == .stopped) {
            thorvg.frame(no: 0.0)
            return
        }
        
        do {
            try thorvg.clear()
        }
         catch {
            print( "Clear error" )
        }
        
        if animationModel.mode == .forward  {
            self.forwardTick()
        } else if animationModel.mode == .reverse {
            self.reverseTick()
        } else if animationModel.mode == .bounce {
            self.bounceTick()
        } else if animationModel.mode == .bounceReverse {
            self.bounceReverseTick()
        }
        
//        if (self.animationModel.speed > 1) {
//            // Original frame rate in frames per second (fps)
//            let originalFPS: Float32 = 30.0
//            
//            // Speed-up factor (e.g., 2.0 for 2x speed)
//            let speedUpFactor: Int = self.animationModel.speed
//            
//            // Calculate the original time between frames (deltaTime)
//            let originalDeltaTime: Float32 = 1.0 / originalFPS
//            
//            // Calculate the new time between frames (newDeltaTime) based on the speed-up factor
//            let newDeltaTime: Float32 = originalDeltaTime / Float32(speedUpFactor)
//            
//            // Calculate the new frame number to be displayed
//            var spedUpFrame = (((newFrame) * originalDeltaTime / newDeltaTime)).rounded()
//            
//            if spedUpFrame >= totalFrames - 1 {
//                spedUpFrame = 0
//            }
//            
//            thorvg.frame(no: spedUpFrame)
//        } else {
//            thorvg.frame(no: newFrame)
//        }
        
        thorvg.draw()
    }
    
    private func fetchAndPlayAnimationFromDotLottie(url: String) {
        if let url = URL(string: url) {
            fetchDotLottieAndUnzipAndWriteToDisk(url: url) { path in
                if let filePath = path {
                    
                    do {
                        let (animWidth, animHeight) = try getAnimationWidthHeight(filePath: filePath)
                        self.loadAnimation(path: filePath.path, width: animWidth != nil ? animWidth : self.animationModel.width, height: animHeight != nil ? animHeight : self.animationModel.height)
                    } catch let error {
                        print(error)
                        self.callCallbacks(event: .onLoadError)
                    }
                    
                } else {
                    print("Failed to load data from : \(url)")
                    
                    self.callCallbacks(event: .onLoadError)
                }
            }
        } else {
            print("Invalid URL")
            
            callCallbacks(event: .onLoadError)
        }
    }
    
    private func fetchAndPlayAnimationFromBundle(url: String) {
        fetchJsonFromBundle(animation_name: url) { string in
            if let animationData = string {
                self.loadAnimation(animationData: animationData, width: self.animationModel.width, height: self.animationModel.height)
            } else {
                print("Failed to load data from main bundle.")
                
                self.callCallbacks(event: .onLoadError)
            }
        }
    }
    
    private func fetchAndPlayAnimationFromURL(url: String) {
        if let url = URL(string: url) {
            fetchJsonFromUrl(url: url) { string in
                if let animationData = string {
                    
                    self.loadAnimation(animationData: animationData, width: self.animationModel.width, height: self.animationModel.height)
                } else {
                    print("Failed to load data from URL.")
                    
                    self.callCallbacks(event: .onLoadError)
                }
            }
        } else {
            print("Invalid URL")
            
            callCallbacks(event: .onLoadError)
        }
    }
    
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

#if os(iOS)
    public func setBackgroundColor(bgColor: UIColor) {
        self.bgColor = bgColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        bgColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        print(UInt8(red), UInt8(green), UInt8(blue), UInt8(alpha))
        thorvg.setBackgroundColor(r: UInt8(red) * 255, g: UInt8(green)  * 255, b: UInt8(blue)  * 255, a: UInt8(alpha) * 255)
    }

    public func backgroundColor() -> UIColor {
        return self.bgColor ?? UIColor.clear
    }
#endif

#if os(macOS)
    public func setBackgroundColor(bgColor: NSColor) {
        self.bgColor = bgColor
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        bgColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        thorvg.setBackgroundColor(r: UInt8(red), g: UInt8(green), b: UInt8(blue), a: UInt8(alpha))
    }

    public func backgroundColor() -> NSColor {
        return self.bgColor ?? NSColor.clear
    }
#endif

    public func play() {
        self.prevState = self.playerState
        self.playerState = .playing
        
        callCallbacks(event: .onPlay)
    }
    
    public func pause() {
        self.prevState = self.playerState
        self.playerState = .paused
        
        callCallbacks(event: .onPause)
    }
    
    public func stop() {
        if mode() == .forward || mode() == .bounce {
            self.thorvg.frame(no: animationModel.segments?.0 ?? 0.0)
        } else if mode() == .reverse || mode() == .bounceReverse {
            self.thorvg.frame(no: animationModel.segments?.1 ?? self.totalFrames())
        }
        
        self.prevState = self.playerState
        self.playerState = .stopped
        
        callCallbacks(event: .onStop)
    }
    
    public func freeze() {
        self.prevState = self.playerState
        
        self.playerState = .frozen
        
        callCallbacks(event: .onFreeze)
    }
    
    public func unfreeze() {
        self.playerState = self.prevState ?? .paused
        
        callCallbacks(event: .onUnFreeze)
    }
    
    public func currentFrame() -> Float32 {
        return thorvg.currentFrame()
    }
    
    public func totalFrames() -> Float32 {
        return thorvg.totalFrames()
    }
    
    public func frame(frameNo: Float32) {
        thorvg.frame(no: frameNo)
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
    
    public func setSegments(segments: (Float32, Float32)) {
        var startFrame = segments.0
        var endFrame = segments.1

        if startFrame < 0 {
           startFrame = 0
        } else if startFrame > self.totalFrames() - 1 {
            startFrame = self.totalFrames() - 1
        }
        
        if endFrame < 0 {
           endFrame = 0
        } else if endFrame > self.totalFrames() - 1 {
            endFrame = self.totalFrames() - 1
        }
        
        animationModel.segments = (startFrame, endFrame)
    }
    
    public func setMode(mode: Mode) {
        animationModel.mode = mode
    }

//    public func direction() -> Int {
//        if direction != nil
//            return direction
//        return animationModel.mode == .forward ? 1 : -1
//    }
//
//    public func setDirection(direction: Int) {
//        animationModel.direction = direction
//        thorvg.direction = direction
//    }
//    
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
