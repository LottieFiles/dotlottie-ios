//
//  AnimationModel.swift
//
//
//  Created by Sam on 30/10/2023.
//

import Foundation
import CoreImage

public enum PlayerState {
    case playing
    case paused
    case initial
    case loaded
    case stopped
    case frozen
    case error
}

public struct AnimationModel {
    var width: Int = 512
    
    var height: Int = 512

    var error: Bool = false
    
    var errorMessage: String = ""
    
    var backgroundColor: CIImage = CIImage.clear
}
