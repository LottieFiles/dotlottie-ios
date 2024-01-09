//
//  File.swift
//  
//
//  Created by Sam on 31/10/2023.
//

import Foundation

struct ManifestModel: Codable {
    var activeAnimationId: String?
    
    var animations: [ManifestAnimationModel]
    
    var author: String?
    
//    var custom: [String: Any]?
    
    var description: String?
    
    var generator: String?
    
    var keywords: String?
    
    var revision: Double?
    
//    var themes: [ManifestThemeSchema]?
    
    var states: [String]?
    
    var version: String?
}
