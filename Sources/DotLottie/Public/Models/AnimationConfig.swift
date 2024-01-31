//
//  File.swift
//
//
//  Created by Sam on 31/01/2024.
//

import CoreImage
import Foundation

public struct AnimationConfig {
    public var autoplay: Bool? = false
    public var loopAnimation: Bool? = false
    public var mode: Mode? = .forward
    public var speed: Float? = 1
    public var useFrameInterpolation: Bool? = false
    public var segments: (Float, Float)? = nil
    public var backgroundColor: CIImage? = .clear
    public var width: Int? = 512
    public var height: Int? = 512
    
    public init(
        autoplay: Bool? = false,
        loopAnimation: Bool? = false,
        mode: Mode? = .forward,
        speed: Float? = 1,
        useFrameInterpolation: Bool? = true,
        segments: (Float, Float)? = nil,
        backgroundColor: CIImage? = .clear,
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.autoplay = autoplay
        self.loopAnimation = loopAnimation
        self.mode = mode
        self.speed = speed
        self.useFrameInterpolation = useFrameInterpolation
        self.segments = segments
        self.backgroundColor = backgroundColor
        self.width = width
        self.height = height
    }
}
