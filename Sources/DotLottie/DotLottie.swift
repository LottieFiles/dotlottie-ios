//
//  DotLottieView.swift
//  
//
//  Created by Sam on 25/10/2023.
//

import Metal
import MetalKit
import CoreImage
import SwiftUI
import AVFoundation

public struct DotLottie: UIViewRepresentable {
    public typealias UIViewType = MTKView
    var mtkView: MTKView = MTKView()
    var width: UInt32;
    var height: UInt32;
    let opaqueBackground: CIImage
    
    @State private var image: CGImage?
    var dotLottiePlayer: DotLottieCore = DotLottieCore();

    public init(animation_data: String, width: UInt32, height: UInt32, backgroundColor: CIImage = CIImage.white) {
        dotLottiePlayer.load_animation(animation_data: animation_data, width: width, height: height);
        
        self.width = width
        self.height = height
        
        self.opaqueBackground = backgroundColor
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self, mtkView: self.mtkView)
    }
    
    public func makeUIView(context: UIViewRepresentableContext<DotLottie>) -> MTKView {
        self.mtkView.isOpaque = true
        self.mtkView.framebufferOnly = false
        self.mtkView.isOpaque = false
        self.mtkView.delegate = context.coordinator
        self.mtkView.preferredFramesPerSecond = 30
        self.mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        self.mtkView.enableSetNeedsDisplay = true
        self.mtkView.isPaused = false
        
        return mtkView
    }
    
    public func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<DotLottie>) {
    }
    
    public func togglePause() {
        self.mtkView.isPaused = !self.mtkView.isPaused;
    }
    
    public func setSpeed(speed: Int) {
        self.mtkView.preferredFramesPerSecond = 30 * speed;
    }
    
    public class Coordinator : NSObject, MTKViewDelegate {
        var parent: DotLottie
        var ciContext: CIContext!
        var metalDevice: MTLDevice!

        var metalCommandQueue: MTLCommandQueue!
        var mtlTexture: MTLTexture!

        init(_ parent: DotLottie, mtkView: MTKView) {
            self.parent = parent
            
            super.init()

            if let metalDevice = MTLCreateSystemDefaultDevice() {
                mtkView.device = metalDevice
                self.metalDevice = metalDevice
            }
            
            self.ciContext = CIContext(mtlDevice: metalDevice, options: [.cacheIntermediates: false, .allowLowPower: true])
            self.metalCommandQueue = metalDevice.makeCommandQueue()!
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        }
        
        public func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable else {
                return
            }
            
            parent.dotLottiePlayer.tick()
            let frame = parent.dotLottiePlayer.render()!

            let commandBuffer = metalCommandQueue.makeCommandBuffer()

            let inputImage = CIImage(cgImage: frame)
            var size = view.bounds
        
            size.size = view.drawableSize
            size = AVMakeRect(aspectRatio: inputImage.extent.size, insideRect: size)
  
            var filteredImage = inputImage.transformed(by: CGAffineTransform(
                scaleX: size.size.width / inputImage.extent.size.width,
                y: size.size.height / inputImage.extent.size.height))
        
            let x = -size.origin.x
            let y = -size.origin.y
            
            // Blend the image over an opaque background image.
            // This is needed if the image is smaller than the view, or if it has transparent pixels.
            filteredImage = filteredImage.composited(over: parent.opaqueBackground)
            
            self.mtlTexture = drawable.texture
                        
            ciContext.render(filteredImage,
                to: drawable.texture,
                commandBuffer: commandBuffer,
                             bounds: CGRect(origin:CGPoint(x:x, y:y), size: view.drawableSize),
                colorSpace: CGColorSpaceCreateDeviceRGB())

            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}
