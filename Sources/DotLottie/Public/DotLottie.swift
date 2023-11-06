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
public class DotLottie: ObservableObject, PlayerEvents {
    // Our model containing the playback settings of the current animation
    @Published private var model: AnimationModel = AnimationModel(id: "animation_0")
    
    var callbacks: [AnimationEvent: [() -> Void]] = [:]
    
    private var thorvg: Thorvg
    
#if os(iOS)
    var backgroundColor: UIColor?
#elseif os(macOS)
    var backgroundColor: NSColor?
#endif
    
    var stopped = false
    
    public init(
        animationData: String?,
        direction: Int?,
        loop: Bool?,
        autoplay: Bool?,
        speed: Int?,
        playMode: PlayMode?,
        defaultActiveAnimation: Bool?,
        width: UInt32?,
        height: UInt32?) {
            thorvg = Thorvg()

            model.direction = direction ?? model.direction
            model.loop = loop ?? model.loop
            model.autoplay = autoplay ?? model.autoplay
            model.speed = speed ?? model.speed
            model.playMode = playMode ?? model.playMode
            model.defaultActiveAnimation = defaultActiveAnimation ?? model.defaultActiveAnimation
            
            if let data = animationData {
                if (!thorvg.loadAnimation(animationData: data, width: width ?? 512, height: height ?? 512)) {
                    model.error = true
                    
                    return
                }
            }
            
            self.model.playing = model.autoplay
        }
    
    // Todo: Manage swapping out animation at runtime
    public func loadAnimation(animationData: String, width: UInt32, height: UInt32) -> Bool {
        if (!thorvg.loadAnimation(animationData: animationData, width: width, height: height)) {
            callCallbacks(event: .onLoadError)
            
            return false;
        }
        
        // Go to the last frame if we're playing backwards
        if (model.direction == -1) {
            thorvg.frame(no: thorvg.totalFrame() - 1)
        }

        // Fire load event
        callCallbacks(event: .onLoad)
        
        return true
    }
    
    // Give the view an image to render
    public func render() -> CGImage? {
        return thorvg.render()
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
        
        if model.direction == 1  {
            if currentFrame > 0 && currentFrame >= totalFrames - 1.0 {
                thorvg.frame(no: 0.0);
                
                // If we're not looping - Set playing to false
                if (!model.loop) {
                    model.playing = false
                    
                    callCallbacks(event: .onComplete)
                } else {
                    callCallbacks(event: .onLoop)
                }
            } else {
                thorvg.frame(no: currentFrame + 1.0);

                callCallbacks(event: .onFrame)
            }
        } else if model.direction == -1 {
            if currentFrame <= 0 {
                thorvg.frame(no: totalFrames - 1.0);
                
                // If we're not looping - Set playing to false
                if (!model.loop) {
                    model.playing = false
                    
                    callCallbacks(event: .onComplete)
                } else {
                    callCallbacks(event: .onLoop)
                }
            } else {
                thorvg.frame(no: currentFrame - 1.0);
                
                callCallbacks(event: .onFrame)
            }
        }
        
        thorvg.draw()
    }
    
    public func on(event: AnimationEvent, callback: @escaping () -> Void) {
        if callbacks[event] == nil {
            callbacks[event] = []
        }
        callbacks[event]?.append(callback)
    }
    
    private func callCallbacks(event: AnimationEvent) {
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
    
    public func getLoop() -> Bool{
        return model.loop
    }
    
    public func direction(direction: Int) {
        model.direction = direction
        thorvg.direction = direction
    }

    public func getDirection() -> Int {
        return model.direction
    }
}
