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
    public var loop: Bool? = false
    public var loopCount: Int? = 0
    public var mode: Mode? = .forward
    public var speed: Float? = 1
    public var useFrameInterpolation: Bool? = false
    public var segments: (Float, Float)? = nil
    public var backgroundColor: CIImage? = .clear
    public var width: Int? = 512
    public var height: Int? = 512
    public var layout: Layout? = createDefaultLayout()
    public var marker: String? = ""
    public var themeId: String? = ""
    public var stateMachineId: String? = ""
    public var animationId: String? = ""
    
    public init(
        autoplay: Bool? = false,
        loop: Bool? = false,
        loopCount: Int? = 0,
        mode: Mode? = .forward,
        speed: Float? = 1,
        useFrameInterpolation: Bool? = true,
        segments: (Float, Float)? = nil,
        backgroundColor: CIImage? = .clear,
        width: Int? = nil,
        height: Int? = nil,
        layout: Layout? = createDefaultLayout(),
        marker: String? = nil,
        themeId: String? = nil,
        stateMachineId: String? = nil
    ) {
        self.autoplay = autoplay
        self.loop = loop
        self.loopCount = loopCount
        self.mode = mode
        self.speed = speed
        self.useFrameInterpolation = useFrameInterpolation
        self.segments = segments
        self.backgroundColor = backgroundColor
        self.width = width
        self.height = height
        self.layout = layout
        self.marker = marker
        self.themeId = themeId
        self.stateMachineId = stateMachineId
    }
}
