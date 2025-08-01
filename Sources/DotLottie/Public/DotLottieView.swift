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
    private var mtkView: MTKView = MTKView()
    
    @ObservedObject internal var dotLottieViewModel: DotLottieAnimation
    @ObservedObject internal var playerState: Player
    
    public init(dotLottie: DotLottieAnimation) {
        self.dotLottieViewModel = dotLottie
        self.playerState = dotLottie.player
    }
  
    public func makeCoordinator() -> Coordinator {
        Coordinator(self, mtkView: self.mtkView)
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
        
        self.mtkView.enableSetNeedsDisplay = true
        
        self.mtkView.isPaused = !self.playerState.isPlaying()
        
        return mtkView
    }
    
    public func updateView(_ uiView: MTKView, context: Context) {
        if self.playerState.isStopped() || self.playerState.isPaused() || self.playerState.isComplete() {
            // Tell the coordinator to draw the last frame before pausing
            uiView.draw()
            uiView.isPaused = true
        }
        
        if self.playerState.isPlaying() {
            uiView.isPaused = false
        }
        
        if self.playerState.playerState == .draw {
            uiView.draw()
        }
        
        if self.dotLottieViewModel.framerate != 30 {
            uiView.preferredFramesPerSecond = self.dotLottieViewModel.framerate
        }
    }
    
    public func subscribe(observer: Observer) {
        self.dotLottieViewModel.subscribe(observer: observer)
    }
}
