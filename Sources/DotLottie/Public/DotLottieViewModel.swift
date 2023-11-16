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
}

// MARK: - DotLottie

// Currently DotLottie is setup to manage a single animation and its playback settings.
// It manages the lifecycle of a renderer as well as advancing the animation and returning frames to the views.
// The playback loop is left up to the subclasses to manage leaving the implementation open for the most pratical one per platform.
// In the future this class will manage multiple animations contained inside a single .lottie.


// rename to animation?
public class DotLottieViewModel: ObservableObject, PlayerEvents {
    // Model for the current animation
    @Published private var model: AnimationModel = AnimationModel(id: "animation_0")
    
    internal var callbacks: [AnimationEvent: [() -> Void]] = [:]
    
    private var thorvg: Thorvg
    
#if os(iOS)
    private var backgroundColor: UIColor?
#elseif os(macOS)
    private var backgroundColor: NSColor?
#endif
    
    private var stopped = false
    
    public init(
        animationData: String = "",
        fileName: String = "",
        webURL: String = "",
        direction: Int = 1,
        loop: Bool = false,
        autoplay: Bool = false,
        speed: Int = 1,
        playMode: PlayMode = PlayMode.normal,
        defaultActiveAnimation: Bool = false,
        width: UInt32 = 512,
        height: UInt32 = 512) {
            thorvg = Thorvg()
            
            model.width = model.width
            model.height = model.height
            model.direction = direction
            model.loop = loop
            model.autoplay = autoplay
            model.speed = speed
            model.playMode = playMode
            model.defaultActiveAnimation = defaultActiveAnimation
            
            if animationData != "" {
                do {
                    try thorvg.loadAnimation(animationData: animationData, width: width, height: height)
                } catch {
                    model.error = true
                    
                    callCallbacks(event: .onLoadError)
                }
            } else if webURL != "" {
                if webURL.contains(".lottie") {
                    print("Fetching dotLottie...")
                    fetchAndPlayAnimationFromDotLottie(url: webURL)
                } else {
                    loadAnimation(webURL: webURL, width: width, height: height)
                }
            } else if fileName != "" {
                loadAnimation(fileName: fileName, width: width, height: height)
            }
            
            self.model.playing = model.autoplay
        }
    
    // Todo: Manage swapping out animation at runtime
    public func loadAnimation(animationData: String, width: UInt32?, height: UInt32?) {
        do {
            try thorvg.loadAnimation(animationData: animationData, width: width ?? self.model.width, height: height ?? self.model.height)
            
            // Go to the last frame if we're playing backwards
            if (model.direction == -1) {
                thorvg.frame(no: thorvg.totalFrame() - 1)
            }
            
            DispatchQueue.main.async{
                self.model.playing = self.model.autoplay
            }
        } catch {
            model.error = true
            
            model.playing = false
            
            callCallbacks(event: .onLoadError)
        }
        
        // Fire load event
        callCallbacks(event: .onLoad)
    }
    
    public func loadAnimation(path: String, width: UInt32?, height: UInt32?) {
        do {
            try thorvg.loadAnimation(path: path, width: width ?? self.model.width, height: height ?? self.model.height)
            
            // Go to the last frame if we're playing backwards
            if (model.direction == -1) {
                thorvg.frame(no: thorvg.totalFrame() - 1)
            }
            
            DispatchQueue.main.async{
                self.model.playing = self.model.autoplay
            }
        } catch let error {
            DispatchQueue.main.async {
                self.model.error = true
                
                self.model.playing = false
            }
            
            print("Error loading from thorvg: \(error)")
            
            callCallbacks(event: .onLoadError)
        }
        
        // Fire load event
        callCallbacks(event: .onLoad)
    }
    
    
    public func loadAnimation(webURL: String, width: UInt32?, height: UInt32?) {
        self.model.width = width ?? self.model.width
        self.model.height = height ?? self.model.height
        
        fetchAndPlayAnimationFromURL(url: webURL)
    }
    
    public func loadAnimation(fileName: String, width: UInt32?, height: UInt32?) {
        self.model.width = width ?? self.model.width
        self.model.height = height ?? self.model.height
        
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
        if (model.error) {
            return
        }
        
        if (stopped) {
            thorvg.frame(no: 0.0)
            return
        }
        
        let currentFrame = thorvg.currentFrame();
        let totalFrames = thorvg.totalFrame();
        var newFrame = currentFrame
        
        if model.direction == 1  {
            if currentFrame >= totalFrames - 1.0 {
                newFrame = 0.0
                
                // If we're not looping - Set playing to false
                if (!model.loop) {
                    model.playing = false
                    
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
        } else if model.direction == -1 {
            if currentFrame <= 0 {
                newFrame = totalFrames - 1.0
                
                // If we're not looping - Set playing to false
                if (!model.loop) {
                    model.playing = false
                    
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
        
        if (self.model.speed > 1) {
            // Original frame rate in frames per second (fps)
            let originalFPS: Float32 = 30.0
            
            // Speed-up factor (e.g., 2.0 for 2x speed)
            let speedUpFactor: Int = self.model.speed
            
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
//                        fetchDotLottieAndUnzip(url: url) { animationData in
//                                if let data = animationData {
                                    fetchDotLottieAndUnzipAndWriteToDisk(url: url) { path in
                                                    if var (filePath) = path {

//                    self.loadAnimation(animationData: data, width: self.model.width, height: self.model.height)
                                                        print("Passing on the file path ! \(filePath)")
                                                        filePath = filePath.replacingOccurrences(of: "file:///", with: "/")
                                                        
                                                        self.loadAnimation(path: filePath, width: self.model.width, height: self.model.height)
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
                self.loadAnimation(animationData: animationData, width: self.model.width, height: self.model.height)
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
                    
                    self.loadAnimation(animationData: animationData, width: self.model.width, height: self.model.height)
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
            for callback in eventCallbacks {
                callback()
            }
        }
    }
    
    public func playing() -> Bool {
        return model.playing
    }
    
    public func autoplay(autoplay: Bool) {
        model.autoplay = autoplay
    }
    
    public func getAutoplay() -> Bool {
        return model.autoplay
    }
    
    public func speed(speed: Int) {
        model.speed = speed
    }
    
    public func getSpeed() -> Int {
        return model.speed
    }
    
    public func duration() -> Float32 {
        return thorvg.duration()
    }
    
    public func play() {
        self.stopped = false
        
        self.model.playing = true
        
        callCallbacks(event: .onPlay)
    }
    
    public func pause() {
        self.stopped = false
        
        self.model.playing = false
        
        callCallbacks(event: .onPause)
    }
    
    public func stop() {
        self.stopped = true
        self.model.playing = false
        
        self.thorvg.frame(no: 0.0)
        
        callCallbacks(event: .onStop)
    }
    
    public func frame(frameNo: Float32) {
        thorvg.frame(no: frameNo)
    }
    
    public func loop(loop: Bool) {
        model.loop = loop
    }
    
    public func getLoop() -> Bool {
        return model.loop
    }
    
    public func direction(direction: Int) {
        model.direction = direction
        thorvg.direction = direction
    }
    
    public func getDirection() -> Int {
        return model.direction
    }
    
    public func view() -> DotLottieView {
        let view: DotLottieView = DotLottieView(dotLottie: self)
        
        return view
    }
}
