//
//  Coordinator.swift
//
//
//  Created by Sam on 03/11/2023.
//

import Foundation
import MetalKit
import AVFoundation

#if os(macOS)
// Custom MTKView that handles mouse events
class InteractiveMTKView: MTKView {
    weak var gestureCoordinator: Coordinator?
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let location = convert(event.locationInWindow, from: nil)
        gestureCoordinator?.handleMouseDown(at: location)
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        let location = convert(event.locationInWindow, from: nil)
        gestureCoordinator?.handleMouseDragged(at: location)
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let location = convert(event.locationInWindow, from: nil)
        gestureCoordinator?.handleMouseUp(at: location)
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let location = convert(event.locationInWindow, from: nil)
        gestureCoordinator?.handleMouseMoved(at: location)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        let location = convert(event.locationInWindow, from: nil)
        gestureCoordinator?.handleMouseEntered(at: location)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        let location = convert(event.locationInWindow, from: nil)
        gestureCoordinator?.handleMouseExited(at: location)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove existing tracking areas
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        // Add new tracking area for hover detection
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Ensure this view receives all mouse events within its bounds
        if self.bounds.contains(point) {
            return self
        }
        return super.hitTest(point)
    }
}
#endif

// Unified Coordinator for all platforms
public class Coordinator: NSObject, MTKViewDelegate {
    private var parent: DotLottie
    private var ciContext: CIContext!
    private var metalDevice: MTLDevice!
    private var metalCommandQueue: MTLCommandQueue!
    private var mtlTexture: MTLTexture!
    private var viewSize: CGSize!    
    
#if os(macOS)
    weak var mtkView: MTKView?
    private var dpr: CGFloat = 1.0
    private var gestureManager: GestureManager!
    private var observerSetup = false
#endif
    
    init(_ parent: DotLottie, mtkView: MTKView) {
        self.parent = parent
#if os(macOS)
        self.mtkView = mtkView
#endif
        super.init()
        
        setupMetal(mtkView: mtkView)
        setupPlatformSpecificGestures(mtkView: mtkView)
    }
    
    // MARK: - Setup Methods
    
#if os(macOS)
    private func setupScreenChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification,
            object: self.mtkView?.window,
            queue: .main
        ) { [weak self] notification in
            self?.dpr = self?.getMaxDPRScale() ?? 1.0
        }
    }
#endif
    
    private func setupMetal(mtkView: MTKView) {
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
            self.metalDevice = metalDevice
        }
        
        self.ciContext = CIContext(mtlDevice: metalDevice, options: [.cacheIntermediates: false, .allowLowPower: true])
        self.metalCommandQueue = metalDevice.makeCommandQueue()!
    }
    
    // iOS gestures are managed through the delegate
    // macOS gestures are managed here
    // Other platforms have to self managed gestures
    private func setupPlatformSpecificGestures(mtkView: MTKView) {
#if os(macOS)
        // Initialize gesture manager for macOS
        self.gestureManager = GestureManager()
        self.gestureManager.gestureManagerDelegate = self
        
        // Set up mouse event handling if this is an InteractiveMTKView
        if let interactiveView = mtkView as? InteractiveMTKView {
            interactiveView.gestureCoordinator = self
            interactiveView.updateTrackingAreas()
        }
#endif
    }
    
    // MARK: - MTKViewDelegate (Shared across all platforms)
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
#if os(macOS)
        self.viewSize = view.bounds.size // Use view bounds (in points) for coordinate conversion
#else
        self.viewSize = size
#endif
        if (!self.parent.dotLottieViewModel.sizeOverrideActive) {
            self.parent.dotLottieViewModel.resize(width: Int(size.width), height: Int(size.height))
        }
        
#if os(macOS)
        // Update tracking areas when view size changes
        if let interactiveView = view as? InteractiveMTKView {
            interactiveView.updateTrackingAreas()
        }
#endif
    }
    
    public func draw(in view: MTKView) {
#if os(macOS)
        // Set up observer on first draw when we know the view is in a window
        if !observerSetup && view.window != nil {
            observerSetup = true
            setupScreenChangeObserver()
            self.dpr = getMaxDPRScale()
        }
#endif
        
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
#if os(iOS)
            // Fix coordinate system for iOS 16.0 only
            if #available(iOS 16.0, *) {
                if #available(iOS 17.0, *) {
                    // iOS 17+ - do nothing
                } else {
                    // iOS 16.x only
                    let flipTransform = CGAffineTransform(scaleX: 1, y: -1)
                    let translateTransform = CGAffineTransform(translationX: 0, y: view.drawableSize.height)
                    filteredImage = filteredImage.transformed(by: flipTransform).transformed(by: translateTransform)
                }
            }
#endif
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
    
    // MARK: - Coordinate Calculation (Shared with platform-specific scaling)
    
    private func calculateCoordinates(location: CGPoint) -> CGPoint {
        // Animation dimensions are in pixels (drawable size)
        let animationWidth = CGFloat(self.parent.dotLottieViewModel.animationModel.width)
        let animationHeight = CGFloat(self.parent.dotLottieViewModel.animationModel.height)
        
        // Calculate scale ratio: animation pixels / view points
        // Note: viewSize is in points, animation dimensions are in pixels
        let scaleRatio = CGPoint(
            x: animationWidth / self.viewSize.width,
            y: animationHeight / self.viewSize.height
        )
        
#if os(iOS)
        let mappedX = location.x * scaleRatio.x * UIScreen.main.scale
        let mappedY = location.y * scaleRatio.y * UIScreen.main.scale
#elseif os(macOS)
        // Flip Y coordinate for macOS (origin is bottom-left on macOS, top-left in animation space)
        let flippedY = self.viewSize.height - location.y
        
        // Convert from view coordinates (points) to animation coordinates (pixels)
        // scaleRatio already accounts for pixel density since animation is in pixels
        let mappedX = location.x * scaleRatio.x
        let mappedY = flippedY * scaleRatio.y
#else
        let mappedX = location.x * scaleRatio.x
        let mappedY = location.y * scaleRatio.y
#endif
        
        return CGPoint(x: mappedX, y: mappedY)
    }
    
#if os(macOS)
    private func getMaxDPRScale() -> CGFloat {
        // Get the DPR of the screen where the window is currently displayed
        guard let window = mtkView?.window,
              let screen = window.screen else {
            // Fallback to main screen if we can't find the window's screen
            let fallbackDpr = NSScreen.main?.backingScaleFactor ?? 1.0
            return fallbackDpr
        }
        
        return screen.backingScaleFactor
    }
#endif
    
    // MARK: - Event Posting (Shared)
    
    private func postEvent(_ event: Event) {
        let _ = self.parent.dotLottieViewModel.stateMachinePostEvent(event)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Platform-Specific Extensions

#if os(iOS)
extension Coordinator: UIGestureRecognizerDelegate, GestureManagerDelegate {
    // UIGestureRecognizerDelegate: Allow simultaneous recognition
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // GestureManagerDelegate methods for iOS
    func gestureManagerDidRecognizeTap(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.click(x: Float(mapped.x), y: Float(mapped.y))
        postEvent(event)
    }
    
    func gestureManagerDidRecognizeMove(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.pointerMove(x: Float(mapped.x), y: Float(mapped.y))
        postEvent(event)
    }
    
    func gestureManagerDidRecognizeDown(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.pointerDown(x: Float(mapped.x), y: Float(mapped.y))
        postEvent(event)
    }
    
    func gestureManagerDidRecognizeUp(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.pointerUp(x: Float(mapped.x), y: Float(mapped.y))
        postEvent(event)
    }
}

#elseif os(macOS)
extension Coordinator: GestureManagerDelegate {
    // MARK: - Mouse Event Handlers (called by InteractiveMTKView)
    
    func handleMouseDown(at location: CGPoint) {
        gestureManager.handleMouseDown(at: location)
    }
    
    func handleMouseDragged(at location: CGPoint) {
        gestureManager.handleMouseDragged(at: location)
    }
    
    func handleMouseUp(at location: CGPoint) {
        gestureManager.handleMouseUp(at: location)
    }
    
    func handleMouseMoved(at location: CGPoint) {
        gestureManager.handleMouseMoved(at: location)
    }
    
    func handleMouseEntered(at location: CGPoint) {
        gestureManager.handleMouseEntered(at: location)
    }
    
    func handleMouseExited(at location: CGPoint) {
        gestureManager.handleMouseExited(at: location)
    }
    
    // MARK: - GestureManagerDelegate methods for macOS
    
    func gestureManagerDidRecognizeTap(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.click(x: Float(mapped.x), y: Float(mapped.y))
        postEvent(event)
    }
    
    func gestureManagerDidRecognizeMove(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.pointerMove(x: Float(mapped.x), y: Float(mapped.y))
        postEvent(event)
    }
    
    func gestureManagerDidRecognizeDown(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.pointerDown(x: Float(mapped.x), y: Float(mapped.y))
        postEvent(event)
    }
    
    func gestureManagerDidRecognizeUp(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.pointerUp(x: Float(mapped.x), y: Float(mapped.y))
        postEvent(event)
    }
    
    func gestureManagerDidRecognizeHover(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.pointerEnter(x: Float(mapped.x), y: Float(mapped.y))
        postEvent(event)
    }
    
    func gestureManagerDidRecognizeExitHover(_ gestureManager: GestureManager, at location: CGPoint) {
        let mapped = calculateCoordinates(location: location)
        let event = Event.pointerExit(x: Float(mapped.x), y: Float(mapped.y))
        postEvent(event)
    }
}
#endif
