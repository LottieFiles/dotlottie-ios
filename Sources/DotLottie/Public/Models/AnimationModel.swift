//
//  File.swift
//  
//
//  Created by Sam on 30/10/2023.
//

import Foundation
import CoreImage

public enum PlayerState {
    case playing
    case paused
    case stopped
    case frozen
    case error
}

public enum Mode: Decodable {
    // From start to end
    case forward

    // From end to start
    case reverse

    // From start to end -> end to start
    case bounce

    // From end to start -> start to end
    case bounceReverse
}


/// <#Description#>
public struct AnimationModel {
    var width: Int = 512
    
    var height: Int = 512
    
    var loop: Bool = false
    
    var autoplay: Bool = false
    
    var speed: Int = 1
    
    var segments: (Float, Float)?
    
    var mode: Mode = .forward
    
    var error: Bool = false
    
    var errorMessage: String = ""
    
    var backgroundColor: CIImage = CIImage.white
}

public struct PlaybackConfig {
    var width: Int = 512
    
    var height: Int = 512
    
    var loop: Bool = false
    
    var autoplay: Bool = false
    
    var speed: Int = 1
    
    var segments: (Float, Float) = (-1,-1)
    
    var mode: Mode = .forward
    
    var backgroundColor: CIImage = CIImage.white
    
    public init(width: Int = 512, height: Int = 512, loop: Bool = false, autoplay: Bool = false, speed: Int = 1, segments: (Float, Float) = (-1,-1), mode: Mode = .forward, backgroundColor: CIImage = .white) {
        self.width = width
        self.height = height
        self.loop = loop
        self.autoplay = autoplay
        self.speed = speed
        self.segments = segments
        self.mode = mode
        self.backgroundColor = backgroundColor
    }
}
