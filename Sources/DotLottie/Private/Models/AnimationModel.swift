//
//  File.swift
//  
//
//  Created by Sam on 30/10/2023.
//

import Foundation

public struct AnimationModel {
    var animationData: String?
    
    var width: UInt32 = 512
    
    var height: UInt32 = 512
    
    var error: Bool = false
    
    var id: String
    
    var url: String?
    
    var direction: Int = 1
    
    var loop: Bool = false
    
    var autoplay: Bool = false

    var playing: Bool = false
    
    var speed: Int = 1
    
    var playMode: PlayMode = PlayMode.normal
        
    var defaultActiveAnimation: Bool = false
}

public enum PlayMode: Hashable {
    // From start to end
    case normal
    
    // From start to end -> end to start
    case bounce
}
