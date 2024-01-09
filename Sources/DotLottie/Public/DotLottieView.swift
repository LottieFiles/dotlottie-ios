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

// View for SwiftUI and MacOS
public struct DotLottieView: ViewRepresentable, DotLottie {
    public typealias UIViewType = MTKView
    private var mtkView: MTKView = MTKView()
    
    @ObservedObject internal var dotLottieViewModel: DotLottieAnimation
    
    public init(dotLottie: DotLottieAnimation) {
        self.dotLottieViewModel = dotLottie
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self, mtkView: self.mtkView)
    }
    
    public func makeView(context: Context) -> MTKView {
#if os(iOS)
        self.mtkView.isOpaque = false
#endif
        
        self.mtkView.framebufferOnly = false
        
        self.mtkView.delegate = context.coordinator
        
        self.mtkView.preferredFramesPerSecond = self.dotLottieViewModel.framerate
        
        self.mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        self.mtkView.enableSetNeedsDisplay = true
        
        self.mtkView.isPaused = !self.dotLottieViewModel.isPlaying()
        
        return mtkView
    }
    
    public func updateView(_ uiView: MTKView, context: Context) {
        if self.dotLottieViewModel.isStopped() {
            // Tell the coordinator to draw the last frame before pausing
            uiView.draw()
            uiView.isPaused = true
        } else if self.dotLottieViewModel.isPaused() {
            // Tell the coordinator to draw the last frame before pausing
            uiView.draw()
            uiView.isPaused = true
        } else if self.dotLottieViewModel.isPlaying() {
            uiView.isPaused = false
        } else if self.dotLottieViewModel.isFrozen() {
            uiView.isPaused = true
        }
        
        if self.dotLottieViewModel.framerate != 30 {
            uiView.preferredFramesPerSecond = self.dotLottieViewModel.framerate
        }
    }
    
    public func on(event: AnimationEvent, callback: @escaping () -> Void) {
        self.dotLottieViewModel.on(event: event, callback: callback)
    }
}
