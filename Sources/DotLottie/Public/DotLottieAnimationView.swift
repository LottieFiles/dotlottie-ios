//
//  File.swift
//
//
//  Created by Sam on 14/11/2023.
//

#if os(iOS)

import Foundation
import UIKit
import Metal
import MetalKit
import CoreImage
import AVFoundation
import Combine

public class DotLottieAnimationView: UIView, DotLottie {
    private var metalView: MTKView!
    private var coordinator: Coordinator!

    var dotLottieViewModel = DotLottieAnimation()
    var cancellableBag = Set<AnyCancellable>()
    
    public var opaqueBackground: CIImage = CIImage.red
    
    let framerate: Int = 60
    
    public init(dotLottieViewModel: DotLottieAnimation) {
        self.dotLottieViewModel = dotLottieViewModel
        
        super.init(frame: .zero)
                
        // React to changes inside the DotLottieModels
        dotLottieViewModel.$animationModel.sink { value in
            if self.metalView != nil {
                self.metalView.isPaused = !(value.playerState == PlayerState.playing)
            }
        }.store(in: &cancellableBag)
        
        setupMetalView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMetalView() {
        metalView = MTKView(frame: bounds)
        
        self.coordinator = Coordinator(self, mtkView: metalView)
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            metalView.device = metalDevice
        }
        
        // Set up Metal-related configurations for your MTKView
        metalView.device = MTLCreateSystemDefaultDevice()
        
        metalView.isOpaque = false
        
        metalView.framebufferOnly = false
        
        metalView.delegate = self.coordinator
        
        metalView.preferredFramesPerSecond = self.framerate * self.dotLottieViewModel.speed()
        
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        metalView.enableSetNeedsDisplay = true
        
        metalView.isPaused = !self.dotLottieViewModel.isPlaying()
        
        addSubview(metalView)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        metalView.frame = bounds
    }
    
    public func on(event: AnimationEvent, callback: @escaping () -> Void) {
        self.dotLottieViewModel.on(event: event, callback: callback)
    }
}

#endif
