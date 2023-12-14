//
//  File.swift
//  
//
//  Created by Sam on 31/10/2023.
//

import Foundation

struct ManifestAnimationModel: Decodable {
    var autoplay: Bool?
    
    var defaultTheme: String?
    
    var direction: Int?
    
    var hover: Bool?
    
    var id: String
    
    var intermission: Double?
    
    var loop: Bool?
    
    var playMode: String?
    
    var speed: Int?
    
    /// Deprecated - Use backgroundColor
    var themeColor: String?
    
    var backgroundColor: String?
}
