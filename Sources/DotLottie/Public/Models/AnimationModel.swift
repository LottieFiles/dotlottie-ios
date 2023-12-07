//
//  File.swift
//  
//
//  Created by Sam on 30/10/2023.
//

import Foundation
#if os(iOS)
import CoreImage
#endif

public enum PlayerState {
    case playing
    case paused
    case stopped
    case frozen
    case error
}

public enum Mode {
    // From start to end
    case forward

    // From end to start
    case reverse

    // From start to end -> end to start
    case bounce

    // From end to start -> start to end
    case bounceReverse
}

/**
    Settings for a single animation
 */
public struct AnimationModel {
    var animationData: String?
    
    var url: String?
    
    var width: Int = 512
    
    var height: Int = 512
    
    var id: String
    
    var loop: Bool = false
    
    var autoplay: Bool = false
    
    var speed: Int = 1
    
    var segments: (Float, Float)?
    
    var mode: Mode = .forward
    
    var defaultActiveAnimation: Bool = false
    
    var error: Bool = false
    
    var backgroundColor: CIImage = CIImage.white
}
