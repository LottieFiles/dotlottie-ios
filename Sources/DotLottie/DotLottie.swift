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

public struct DotLottie: UIViewRepresentable {
    public typealias UIViewType = MTKView
    var mtkView: MTKView
    
    @State private var image: CGImage?
    var dotLottiePlayer: DotLottieCore = DotLottieCore();

    public init(animation_data: String, width: UInt32, height: UInt32) {
        dotLottiePlayer.load_animation(animation_data: animation_data, width: width, height: height);
        
        mtkView = MTKView()
    }
            
    public func makeCoordinator() -> Coordinator {
        Coordinator(self, mtkView: mtkView)
    }
    
    public func makeUIView(context: UIViewRepresentableContext<DotLottie>) -> MTKView {
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 30
        mtkView.backgroundColor = context.environment.colorScheme == .dark ? UIColor.white : UIColor.white
        mtkView.isOpaque = true
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        
        return mtkView
    }
    
    public func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<DotLottie>) {
    }
    
    func togglePause() {
        self.mtkView.isPaused = !self.mtkView.isPaused;
    }
    
    func setSpeed(speed: Int) {
        self.mtkView.preferredFramesPerSecond = 30 * speed;
    }
    
    public class Coordinator : NSObject, MTKViewDelegate {
        var parent: DotLottie
        var ciContext: CIContext!
        var metalDevice: MTLDevice!

        var metalCommandQueue: MTLCommandQueue!
        var mtlTexture: MTLTexture!
                
        var startTime: Date!
        init(_ parent: DotLottie, mtkView: MTKView) {
            self.parent = parent
            if let metalDevice = MTLCreateSystemDefaultDevice() {
                mtkView.device = metalDevice
                self.metalDevice = metalDevice
            }
            self.ciContext = CIContext(mtlDevice: metalDevice)
            self.metalCommandQueue = metalDevice.makeCommandQueue()!
            
            super.init()
            mtkView.framebufferOnly = false
            mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            mtkView.drawableSize = mtkView.frame.size
            mtkView.enableSetNeedsDisplay = true
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        }
        
        public func draw(in view: MTKView) {
            if (view.isPaused) {
                return ;
            }
            guard let drawable = view.currentDrawable else {
                return
            }
            
            parent.dotLottiePlayer.tick()
            let frame = parent.dotLottiePlayer.render()!
            print("Rendering");
            
            let commandBuffer = metalCommandQueue.makeCommandBuffer()
//            let inputImage = CIImage(mtlTexture: mtlTexture)!
            let inputImage = CIImage(cgImage: frame)
            var size = view.bounds
            size.size = view.drawableSize
//            size = AVMakeRect(aspectRatio: inputImage.extent.size, insideRect: size)
            let filteredImage = inputImage.transformed(by: CGAffineTransform(
                scaleX: size.size.width / inputImage.extent.size.width,
                y: size.size.height / inputImage.extent.size.height))
            let x = -size.origin.x
            let y = -size.origin.y
            
            
            self.mtlTexture = drawable.texture
            ciContext.render(filteredImage,
                to: drawable.texture,
                commandBuffer: commandBuffer,
                bounds: CGRect(origin:CGPoint(x:x, y:y), size: view.drawableSize),
                colorSpace: CGColorSpaceCreateDeviceRGB())

            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
        
        func getUIImage(texture: MTLTexture, context: CIContext) -> UIImage?{
            let kciOptions = [CIImageOption.colorSpace: CGColorSpaceCreateDeviceRGB(),
                              CIContextOption.outputPremultiplied: true,
                              CIContextOption.useSoftwareRenderer: false] as! [CIImageOption : Any]
            
            if let ciImageFromTexture = CIImage(mtlTexture: texture, options: kciOptions) {
                if let cgImage = context.createCGImage(ciImageFromTexture, from: ciImageFromTexture.extent) {
                    let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .downMirrored)
                    return uiImage
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
    }
}
