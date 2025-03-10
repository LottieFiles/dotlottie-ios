//
//  Coordinator.swift
//
//
//  Created by Sam on 03/11/2023.
//

import Foundation
import MetalKit
import AVFoundation

public class Coordinator : NSObject, MTKViewDelegate, UIGestureRecognizerDelegate, GestureManagerDelegate {
    private var parent: DotLottie
    private var ciContext: CIContext!
    private var metalDevice: MTLDevice!
    private var metalCommandQueue: MTLCommandQueue!
    private var mtlTexture: MTLTexture!
    private var viewSize: CGSize!

    
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
        self.viewSize = size
        
        if (!self.parent.dotLottieViewModel.sizeOverrideActive) {
            self.parent.dotLottieViewModel.resize(width: Int(size.width), height: Int(size.height))
        }
    }
    
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else {
            return
        }
        
        guard !parent.dotLottieViewModel.error() else {
            return
        }
                
        if let frame = parent.dotLottieViewModel.tick() {
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
            // This is needed if the image is smaller than the view, or if it has transparent
            filteredImage = filteredImage.composited(over: parent.dotLottieViewModel.backgroundColor())
            
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
    
    func calculateCoordinates(location: CGPoint) -> CGPoint {
        let scaleRatio = CGPoint(
            x: CGFloat(self.parent.dotLottieViewModel.animationModel.width) / self.viewSize.width,
            y: CGFloat(self.parent.dotLottieViewModel.animationModel.height) / self.viewSize.height
        )
        
        // Map the touch location to animation coordinates
        let mappedX = location.x * scaleRatio.x * UIScreen.main.scale
        let mappedY = location.y * scaleRatio.y * UIScreen.main.scale
        
        return CGPoint(x: mappedX, y: mappedY)
    }
    
    // UIGestureRecognizerDelegate: Allow simultaneous recognition
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    func gestureManagerDidRecognizeTap(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.click(x: Float(mapped.x), y: Float(mapped.y))
        print("Sending click")
        let _ = self.parent.dotLottieViewModel.stateMachinePostEvent(event)
    }

    
    func gestureManagerDidRecognizeMove(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.pointerMove(x: Float(mapped.x), y: Float(mapped.y))
        let _ = self.parent.dotLottieViewModel.stateMachinePostEvent(event)
    }
    
    func gestureManagerDidRecognizeDown(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.pointerDown(x: Float(mapped.x), y: Float(mapped.y))
        let _ = self.parent.dotLottieViewModel.stateMachinePostEvent(event)
    }
    
    func gestureManagerDidRecognizeUp(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.pointerUp(x: Float(mapped.x), y: Float(mapped.y))
        let _ = self.parent.dotLottieViewModel.stateMachinePostEvent(event)
    }
}
