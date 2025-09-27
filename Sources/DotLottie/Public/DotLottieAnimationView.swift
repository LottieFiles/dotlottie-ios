#if os(iOS)

import Foundation
import UIKit
import Metal
import MetalKit
import CoreImage
import AVFoundation
import Combine

// UIKit animation view
public class DotLottieAnimationView: UIView, DotLottie {
    private var mtkView: MTKView!
    private var coordinator: Coordinator!
    private var cancellableBag = Set<AnyCancellable>()
    
    public var dotLottieViewModel: DotLottieAnimation
    
    public init(dotLottieViewModel: DotLottieAnimation) {
        self.dotLottieViewModel = dotLottieViewModel
        
        super.init(frame: .zero)
        
        dotLottieViewModel.$framerate.sink { [weak self] value in
            if let self, mtkView != nil {
                mtkView.preferredFramesPerSecond = dotLottieViewModel.framerate
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
        
        mtkView.isPaused = false
        
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
