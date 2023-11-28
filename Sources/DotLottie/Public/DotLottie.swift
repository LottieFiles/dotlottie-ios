//
//  File.swift
//  
//
//  Created by Sam on 23/11/2023.
//

import Foundation
import CoreImage

protocol DotLottie {
    var dotLottieViewModel: DotLottieAnimation { get set }
    var opaqueBackground: CIImage { get set }
    func on(event: AnimationEvent, callback: @escaping () -> Void)
}
