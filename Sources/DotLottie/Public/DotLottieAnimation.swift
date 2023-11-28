//
//  File.swift
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
    case onDestroy
}

// MARK: - DotLottie

// Currently DotLottie is setup to manage a single animation and its playback settings.
// It manages the lifecycle of a renderer as well as advancing the animation and returning frames to the views.
// The playback loop is left up to the subclasses to manage leaving the implementation open for the most pratical one per platform.
// In the future this class will manage multiple animations contained inside a single .lottie.


// rename to animation?
public class DotLottieAnimation: ObservableObject, PlayerEvents {
    // Model for the current animation
    // Todo: Does this have to be public?
    @Published public var animationModel: AnimationModel = AnimationModel(id: "animation_0")
    
    internal var callbacks: [AnimationEvent: [() -> Void]] = [:]

    internal var loopCounter: Int = 0

    private var thorvg: Thorvg
    
    
#if os(iOS)
    private var bgColor: UIColor?
#elseif os(macOS)
    private var bgColor: NSColor?
#endif
    
    public init(
        animationData: String = "",
        fileName: String = "",
        webURL: String = "",
        direction: Int = 1,
        loop: Bool = false,
        autoplay: Bool = false,
        speed: Int = 1,
        mode: Mode = .forward,
        defaultActiveAnimation: Bool = false,
        width: UInt32 = 512,
        height: UInt32 = 512) {
            thorvg = Thorvg()
            
            self.setBackgroundColor(bgColor: .orange)
            
            animationModel.width = animationModel.width
            animationModel.height = animationModel.height
            animationModel.direction = direction
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
            
            self.animationModel.playerState = animationModel.autoplay ? .playing : .paused
        }
    
    // Todo: Manage swapping out animation at runtime
    public func loadAnimation(animationData: String, width: UInt32?, height: UInt32?) {
        do {
            try thorvg.loadAnimation(animationData: animationData, width: width ?? self.animationModel.width, height: height ?? self.animationModel.height)
            
            // Go to the last frame if we're playing backwards
            if (animationModel.direction == -1) {
                thorvg.frame(no: self.totalFrames() - 1)
            }
            
            DispatchQueue.main.async{
                self.animationModel.playerState = self.animationModel.autoplay ? .playing : .paused
            }
        } catch {
            animationModel.error = true
            
            self.animationModel.playerState = .paused
            
            callCallbacks(event: .onLoadError)
        }
        
        // Fire load event
        callCallbacks(event: .onLoad)
    }
    
    public func loadAnimation(path: String, width: UInt32?, height: UInt32?) {
        do {
            try thorvg.loadAnimation(path: path, width: width ?? self.animationModel.width, height: height ?? self.animationModel.height)
            
            // Go to the last frame if we're playing backwards
            if (animationModel.direction == -1) {
                thorvg.frame(no: self.totalFrames() - 1)
            }
            
            DispatchQueue.main.async{
                self.animationModel.playerState = self.animationModel.autoplay ? PlayerState.playing : PlayerState.paused
            }
        } catch let error {
            DispatchQueue.main.async {
                self.animationModel.error = true
                
                self.animationModel.playerState = .paused
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
    
    public func tick() {
        if (animationModel.error) {
            return
        }
        
        if (animationModel.playerState == .stopped) {
            thorvg.frame(no: 0.0)
            return
        }
        
        do {
            try thorvg.clear()
        }
         catch {
            print( "Clear error" )
        }
        
        let currentFrame = self.currentFrame();
        let totalFrames = self.totalFrames();
        var newFrame = currentFrame
        
        if animationModel.direction == 1  {
            if currentFrame >= totalFrames - 1.0 {
                newFrame = 0.0
                
                // If we're not looping - Set playing to false
                if (!animationModel.loop) {
                    animationModel.playerState = .paused
    
                    callCallbacks(event: .onComplete)
                    thorvg.draw()
                    return
                } else {
                    callCallbacks(event: .onLoop)
                }
            } else {
                newFrame = currentFrame + 1.0
                
                callCallbacks(event: .onFrame)
            }
        } else if animationModel.direction == -1 {
            if currentFrame <= 0 {
                newFrame = totalFrames - 1.0
                
                // If we're not looping - Set playing to false
                if (!animationModel.loop) {
                    animationModel.playerState = .paused
                    
                    callCallbacks(event: .onComplete)
                    thorvg.draw()
                    return
                } else {
                    callCallbacks(event: .onLoop)
                }
            } else {
                newFrame = currentFrame - 1.0
                
                callCallbacks(event: .onFrame)
            }
        }
        
        if (self.animationModel.speed > 1) {
            // Original frame rate in frames per second (fps)
            let originalFPS: Float32 = 30.0
            
            // Speed-up factor (e.g., 2.0 for 2x speed)
            let speedUpFactor: Int = self.animationModel.speed
            
            // Calculate the original time between frames (deltaTime)
            let originalDeltaTime: Float32 = 1.0 / originalFPS
            
            // Calculate the new time between frames (newDeltaTime) based on the speed-up factor
            let newDeltaTime: Float32 = originalDeltaTime / Float32(speedUpFactor)
            
            // Calculate the new frame number to be displayed
            var spedUpFrame = (((newFrame) * originalDeltaTime / newDeltaTime)).rounded()
            
            if spedUpFrame >= totalFrames - 1 {
                spedUpFrame = 0
            }
            
            thorvg.frame(no: spedUpFrame)
        } else {
            thorvg.frame(no: newFrame)
        }
        
        thorvg.draw()
    }
    
    private func fetchAndPlayAnimationFromDotLottie(url: String) {
        if let url = URL(string: url) {
            fetchDotLottieAndUnzipAndWriteToDisk(url: url) { path in
                if let filePath = path {
                    let (width, height) = getAnimationWidthHeight(filePath: filePath)
                    
                    self.loadAnimation(path: filePath.path, width: width != nil ? width : self.animationModel.width, height: height != nil ? height : self.animationModel.height)
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
    
    public func isPlaying() -> Bool {
        return animationModel.playerState == .playing
    }

    public func isPaused() -> Bool {
        return animationModel.playerState == .paused
    }

    public func isStopped() -> Bool {
        return animationModel.playerState == .stopped
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
        self.animationModel.playerState = .playing
        
        callCallbacks(event: .onPlay)
    }
    
    public func pause() {
        self.animationModel.playerState = .paused
        
        callCallbacks(event: .onPause)
    }
    
    public func stop() {
        self.animationModel.playerState = .stopped
        
        self.thorvg.frame(no: 0.0)
        
        callCallbacks(event: .onStop)
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
        return animationModel.segments
    }
    
    public func direction() -> Int {
        return animationModel.direction
    }

    public func setDirection(direction: Int) {
        animationModel.direction = direction
        thorvg.direction = direction
    }
    
    public func view() -> DotLottieView {
        let view: DotLottieView = DotLottieView(dotLottie: self)
        
        return view
    }
    
#if os(iOS)
    public func createDotLottieView() -> DotLottieAnimationView {
        let view: DotLottieAnimationView = DotLottieAnimationView(dotLottieViewModel: self)
        
        return view
    }
#endif
}
