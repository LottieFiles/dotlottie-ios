//
//  File.swift
//
//
//  Created by Sam on 03/11/2023.
//

import Foundation
import MetalKit
import AVFoundation

public class Coordinator : NSObject, MTKViewDelegate {
    private var parent: DotLottieView
    private var ciContext: CIContext!
    private var metalDevice: MTLDevice!
    private var metalCommandQueue: MTLCommandQueue!
    private var mtlTexture: MTLTexture!
    
    init(_ parent: DotLottieView, mtkView: MTKView) {
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
        print("Resizing...")
    }
    
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else {
            return
        }
        
        parent.dotLottie.tick()
        
        if let frame = parent.dotLottie.render() {
            let commandBuffer = metalCommandQueue.makeCommandBuffer()
            
            let inputImage = CIImage(cgImage: frame)
            var size = view.bounds
            
            size.size = view.drawableSize
            size = AVMakeRect(aspectRatio: inputImage.extent.size, insideRect: size)
            
            var filteredImage = inputImage.transformed(by: CGAffineTransform(
                scaleX: size.size.width / inputImage.extent.size.width,
                y: size.size.height / inputImage.extent.size.height))
            
#if targetEnvironment(simulator)
//            filteredImage = filteredImage.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
//                .transformed(by: CGAffineTransform(translationX: 0, y: filteredImage.extent.height))
#endif
            
            let x = -size.origin.x
            let y = -size.origin.y
            
            // Blend the image over an opaque background image.
            // This is needed if the image is smaller than the view, or if it has transparent
            
            // Commented out for the moment due to memory errors
            filteredImage = filteredImage.composited(over: parent.opaqueBackground)
            
            self.mtlTexture = drawable.texture
            
            ciContext.render(filteredImage,
                             to: drawable.texture,
                             commandBuffer: commandBuffer,
                             bounds: CGRect(origin:CGPoint(x:x, y:y), size: view.drawableSize),
                             colorSpace: CGColorSpaceCreateDeviceRGB())
            
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        } else {
            print("NIL frame")
            
            parent.dotLottie.pause()
            return ;
        }
    }
}
