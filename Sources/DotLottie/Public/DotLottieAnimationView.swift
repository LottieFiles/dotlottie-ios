#if os(iOS)

import Foundation
import UIKit
import Metal
import MetalKit
import CoreImage
import AVFoundation
import Combine

public class DotLottieAnimationView: UIView, DotLottie {
    private var mtkView: MTKView!
    private var coordinator: Coordinator!
    private var cancellableBag = Set<AnyCancellable>()
    
    public var dotLottieViewModel: DotLottieAnimation
    
    public init(dotLottieViewModel: DotLottieAnimation) {
        self.dotLottieViewModel = dotLottieViewModel
        
        super.init(frame: .zero)
        
        dotLottieViewModel.player.$playerState.sink { value in
            if self.mtkView != nil {
                self.mtkView.draw()
                
                if self.dotLottieViewModel.isStopped() || self.dotLottieViewModel.isPaused() {
                    // Tell the coordinator to draw the last frame before pausing
                    self.mtkView.isPaused = true
                }
                
                if self.dotLottieViewModel.isPlaying() {
                    self.mtkView.isPaused = false
                }
            }
        }.store(in: &cancellableBag)
        
        dotLottieViewModel.$framerate.sink { value in
            if self.mtkView != nil {
                self.mtkView.preferredFramesPerSecond = dotLottieViewModel.framerate
            }
        }.store(in: &cancellableBag)
        
        
        setupMetalView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMetalView() {
        mtkView = MTKView(frame: bounds)
        
        self.coordinator = Coordinator(self, mtkView: mtkView)
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        
        // Set up Metal-related configurations for your MTKView
        mtkView.device = MTLCreateSystemDefaultDevice()
        
        mtkView.isOpaque = false
        
        mtkView.framebufferOnly = false
        
        mtkView.delegate = self.coordinator
        
        mtkView.preferredFramesPerSecond = self.dotLottieViewModel.framerate
        
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        mtkView.enableSetNeedsDisplay = true
        
        mtkView.isPaused = !self.dotLottieViewModel.isPlaying()
        addSubview(mtkView)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        mtkView.frame = bounds
    }
    
    public func subscribe(observer: Observer) {
        self.dotLottieViewModel.subscribe(observer: observer)
    }
}

#endif
