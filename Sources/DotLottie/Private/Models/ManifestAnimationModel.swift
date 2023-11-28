//
//  File.swift
//  
//
//  Created by Sam on 31/10/2023.
//

import Foundation

struct ManifestAnimationModel {
    var autoplay: Bool?
    
    var defaultTheme: String?
    
    var direction: Int?
    
    var hover: Bool?
    
    var id: String
    
//    var intermission: Double?
    
    var loop: Loop?
    
    var playMode: Mode = Mode.forward
    
    var speed: Double?
    
    /// Deprecated - Use backgroundColor
    var themeColor: String?
    
    var backgroundColor: String?
}

enum Loop {
    case boolean(Bool)
    case number(Int)
}
