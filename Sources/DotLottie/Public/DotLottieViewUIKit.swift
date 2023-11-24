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

public class DotLottieViewUIKit: UIView, DotLottie {
    private var metalView: MTKView!
    private var coordinator: Coordinator!

    var dotLottie = DotLottieViewModel()
    var cancellableBag = Set<AnyCancellable>()
    
    public var opaqueBackground: CIImage = CIImage.red
    
    let framerate: Int = 60
    
    public init(frame: CGRect, dotLottie: DotLottieViewModel) {
        self.dotLottie = dotLottie
        
        super.init(frame: frame)
                
        // React to changes inside the DotLottieModels
        dotLottie.$model.sink { value in
            if self.metalView != nil {
                self.metalView.isPaused = !value.playing
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
        
        metalView.preferredFramesPerSecond = self.framerate * self.dotLottie.getSpeed()
        
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        metalView.enableSetNeedsDisplay = true
        
        metalView.isPaused = !self.dotLottie.playing()
        
        addSubview(metalView)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        metalView.frame = bounds
    }
    
    public func on(event: AnimationEvent, callback: @escaping () -> Void) {
        self.dotLottie.on(event: event, callback: callback)
    }
}

#endif
