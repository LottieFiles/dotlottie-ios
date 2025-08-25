//
//  DotLottieView.swift
//
//
//  Created by Sam on 25/10/2023.
//
//

import Metal
import MetalKit
import CoreImage
import SwiftUI

// SwiftUI animation view
public struct DotLottieView: ViewRepresentable, DotLottie {
    public typealias UIViewType = MTKView
    
#if os(macOS)
    private var mtkView: MTKView = InteractiveMTKView()
#else
    private var mtkView: MTKView = MTKView()
#endif
    
#if os(iOS)
    private let gestureManager = GestureManager()
#endif
    
    @ObservedObject internal var dotLottieViewModel: DotLottieAnimation
    @ObservedObject internal var playerState: Player
    
    public init(dotLottie: DotLottieAnimation) {
        self.dotLottieViewModel = dotLottie
        self.playerState = dotLottie.player
    }
    
    public func makeCoordinator() -> Coordinator {
#if os(iOS)
        return Coordinator(self, mtkView: self.mtkView)
#elseif os(macOS)
        return Coordinator(self, mtkView: self.mtkView)
#else
        return Coordinator(self, mtkView: self.mtkView)
#endif
    }
    
    public func makeView(context: Context) -> MTKView {
#if os(iOS)
        self.mtkView.isOpaque = false
#elseif os(macOS)
        self.mtkView.layer?.isOpaque = false
#endif
        
        self.mtkView.framebufferOnly = false
        
        self.mtkView.delegate = context.coordinator
        
        self.mtkView.preferredFramesPerSecond = self.dotLottieViewModel.framerate
        
        self.mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        self.mtkView.isPaused = false
        
        self.mtkView.enableSetNeedsDisplay = true
        
#if os(iOS)
        // Gesture management
        gestureManager.cancelsTouchesInView = false
        gestureManager.delegate = context.coordinator
        gestureManager.gestureManagerDelegate = context.coordinator
        self.mtkView.addGestureRecognizer(gestureManager)
#endif
        
        return mtkView
    }
    
    public func updateView(_ uiView: MTKView, context: Context) {
        // All animations will be paused if this is not set to false here.
        uiView.isPaused = false
        
        if self.dotLottieViewModel.framerate != 30 {
            uiView.preferredFramesPerSecond = self.dotLottieViewModel.framerate
        }
    }
    
    public func subscribe(observer: Observer) {
        self.dotLottieViewModel.subscribe(observer: observer)
    }
}
