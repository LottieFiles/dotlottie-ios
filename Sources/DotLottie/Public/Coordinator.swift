//
//  Coordinator.swift
//
//
//  Created by Sam on 03/11/2023.
//

#if !os(watchOS)
import Foundation
import MetalKit
import AVFoundation
import QuartzCore

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

/// Blits the player's software frame buffer to the drawable through a small
/// cached pipeline. Replaces the former CoreImage path, which re-uploaded the
/// frame as a brand-new Metal texture every frame (CoreImage cannot cache a
/// texture for a CGImage whose identity changes each frame).
private enum FrameBlitter {
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VSOut {
        float4 position [[position]];
        float2 uv;
    };

    // rect = aspect-fit destination rect as NDC (x0, y0Bottom, x1, y1Top).
    vertex VSOut dotlottieQuadVertex(uint vid [[vertex_id]],
                                     constant float4 &rect [[buffer(0)]]) {
        float2 positions[4] = {
            float2(rect.x, rect.y), float2(rect.z, rect.y),
            float2(rect.x, rect.w), float2(rect.z, rect.w)
        };
        // v=0 is the top row of the frame buffer; NDC +y is up.
        float2 uvs[4] = {
            float2(0, 1), float2(1, 1),
            float2(0, 0), float2(1, 0)
        };
        VSOut out;
        out.position = float4(positions[vid], 0, 1);
        out.uv = uvs[vid];
        return out;
    }

    fragment float4 dotlottieQuadFragment(VSOut in [[stage_in]],
                                          texture2d<float> frame [[texture(0)]]) {
        constexpr sampler s(mag_filter::linear, min_filter::linear);
        return frame.sample(s, in.uv);
    }
    """

    private static var cache: [ObjectIdentifier: [UInt: MTLRenderPipelineState]] = [:]
    private static let cacheLock = NSLock()

    /// One compiled pipeline per (device, pixel format) — shared by every view.
    static func pipeline(device: MTLDevice, pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        let deviceKey = ObjectIdentifier(device)
        if let state = cache[deviceKey]?[pixelFormat.rawValue] {
            return state
        }

        guard let library = try? device.makeLibrary(source: shaderSource, options: nil) else {
            return nil
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "dotlottieQuadVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "dotlottieQuadFragment")
        let attachment = descriptor.colorAttachments[0]!
        attachment.pixelFormat = pixelFormat
        // Frame buffer is premultiplied alpha; blend over the clear color.
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .one
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let state = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }
        cache[deviceKey, default: [:]][pixelFormat.rawValue] = state
        return state
    }
}

// Unified Coordinator for all platforms
public class Coordinator: NSObject, MTKViewDelegate {
    private let viewModel: DotLottieAnimation
    private var metalDevice: MTLDevice!
    private var metalCommandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState?
    /// Reused upload target for the software frame buffer; recreated only when
    /// the animation buffer changes size.
    private var stagingTexture: MTLTexture?
    private var viewSize: CGSize!
    private var lastDrawTime: CFTimeInterval = 0
    /// Cached MTLClearColor for the view background; recomputed only when the
    /// model's background image identity changes.
    private var cachedClearColor = MTLClearColorMake(0, 0, 0, 0)
    private var cachedBackground: CIImage?
    
#if os(macOS)
    weak var mtkView: MTKView?
    private var dpr: CGFloat = 1.0
    private var gestureManager: GestureManager!
    private var observerSetup = false
    private var screenChangeObserver: NSObjectProtocol?
#endif
    
    init(_ parent: DotLottie, mtkView: MTKView) {
        self.viewModel = parent.dotLottieViewModel
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
        // Keep the returned token so deinit can remove this block-based observer.
        screenChangeObserver = NotificationCenter.default.addObserver(
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

        self.metalCommandQueue = metalDevice.makeCommandQueue()!
        self.pipelineState = FrameBlitter.pipeline(device: metalDevice, pixelFormat: mtkView.colorPixelFormat)
    }

    /// Uploads the frame into the reused staging texture, recreating it only
    /// on size changes.
    private func uploadFrame(_ pixels: UnsafeRawPointer, width: Int, height: Int) -> Bool {
        if stagingTexture == nil || stagingTexture!.width != width || stagingTexture!.height != height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = .shaderRead
            #if os(macOS)
            descriptor.storageMode = .managed
            #else
            descriptor.storageMode = .shared
            #endif
            stagingTexture = metalDevice.makeTexture(descriptor: descriptor)
        }
        guard let texture = stagingTexture else { return false }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: 4 * width)
        return true
    }

    /// Resolves the model's background CIImage to a clear color, cached until
    /// the background image identity changes.
    private func currentClearColor() -> MTLClearColor {
        let background = viewModel.backgroundColor()
        if background !== cachedBackground {
            cachedBackground = background
            var rgba = [UInt8](repeating: 0, count: 4)
            let context = CIContext(options: [.useSoftwareRenderer: true])
            context.render(background,
                           toBitmap: &rgba,
                           rowBytes: 4,
                           bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBA8,
                           colorSpace: CGColorSpaceCreateDeviceRGB())
            cachedClearColor = MTLClearColorMake(
                Double(rgba[0]) / 255, Double(rgba[1]) / 255,
                Double(rgba[2]) / 255, Double(rgba[3]) / 255)
        }
        return cachedClearColor
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
        if (!self.viewModel.sizeOverrideActive) {
            self.viewModel.resize(width: Int(size.width), height: Int(size.height))
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
        
        guard !viewModel.error() else {
            return
        }

        let now = CACurrentMediaTime()
        let dt = lastDrawTime == 0 ? Float(0) : Float((now - lastDrawTime) * 1000)
        lastDrawTime = now

        // Zero-copy: the frame buffer goes straight into the reused staging
        // texture — no CGImage, no CoreImage graph, no per-frame texture churn.
        let uploaded = viewModel.tickWithBuffer(milliseconds: dt) { pixels, width, height in
            uploadFrame(pixels, width: width, height: height)
        }
        // nil = no new frame (keep the previous drawable content, as before).
        guard uploaded == true,
              let staging = stagingTexture,
              let pipeline = pipelineState,
              let passDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            return
        }

        passDescriptor.colorAttachments[0].clearColor = currentClearColor()

        // Aspect-fit the frame in the drawable, expressed in NDC.
        let drawableSize = view.drawableSize
        let fit = AVMakeRect(
            aspectRatio: CGSize(width: staging.width, height: staging.height),
            insideRect: CGRect(origin: .zero, size: drawableSize))
        var rect = SIMD4<Float>(
            Float(fit.minX / drawableSize.width * 2 - 1),       // x0
            Float(1 - fit.maxY / drawableSize.height * 2),      // y bottom
            Float(fit.maxX / drawableSize.width * 2 - 1),       // x1
            Float(1 - fit.minY / drawableSize.height * 2))      // y top

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            return
        }
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        encoder.setFragmentTexture(staging, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: - Coordinate Calculation (Shared with platform-specific scaling)
    
    private func calculateCoordinates(location: CGPoint) -> CGPoint {
        // Animation dimensions are in pixels (drawable size)
        let animationWidth = CGFloat(self.viewModel.animationModel.width)
        let animationHeight = CGFloat(self.viewModel.animationModel.height)

        // Calculate scale ratio: animation pixels / view points
        // Note: viewSize is in points, animation dimensions are in pixels
        let scaleRatio = CGPoint(
            x: animationWidth / self.viewSize.width,
            y: animationHeight / self.viewSize.height
        )

#if os(iOS)
        let screenScale = UIScreen.main.scale
        let mappedX = location.x * scaleRatio.x * screenScale
        let mappedY = location.y * scaleRatio.y * screenScale
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
        let _ = self.viewModel.stateMachinePostEvent(event)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
#if os(macOS)
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
#endif
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
#endif // os(macOS)
#endif // !os(watchOS)
