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

// Unified Coordinator for all platforms
public class Coordinator: NSObject, MTKViewDelegate {
    private var parent: DotLottie
    private var metalDevice: MTLDevice!
    private var metalCommandQueue: MTLCommandQueue!
    private var renderPipelineState: MTLRenderPipelineState!
    // Throttles to one in-flight frame so the core never renders the next frame into the shared
    // buffer while the GPU is still reading it for the previous frame.
    private let inFlightSemaphore = DispatchSemaphore(value: 1)
    private var viewSize: CGSize!
    private var lastDrawTime: CFTimeInterval = 0

    // Matches `Params` in the fragment shader.
    private struct FrameParams {
        var width: UInt32
        var height: UInt32
    }

    /// Render-resolution cap: the core renders at most this many pixels on the longer side and
    /// the GPU upscales to the full-resolution drawable. Lower = less memory, softer; raise for
    /// crisper output on large/high-DPI screens.
    private static let maxRenderDimension: CGFloat = 1600
    
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

        self.metalCommandQueue = metalDevice.makeCommandQueue()!
        buildRenderPipeline(mtkView: mtkView)

        // Let the core render straight into GPU-visible memory (zero-copy); the shader reads it.
        self.parent.dotLottieViewModel.setMetalDevice(self.metalDevice)
    }

    /// Builds a minimal fullscreen-quad pipeline whose fragment shader reads the core's
    /// premultiplied RGBA8 render buffer **directly** (bilinear) and upscales it to the
    /// drawable. This replaces the previous Core Image path (which loaded Core Image's
    /// heavyweight Metal kernel library) and avoids any extra full-resolution texture/copy.
    private func buildRenderPipeline(mtkView: MTKView) {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VOut {
            float4 position [[position]];
            float2 uv;
        };

        struct Params {
            uint width;
            uint height;
        };

        vertex VOut dl_vertex(uint vid [[vertex_id]]) {
            // Fullscreen quad as a triangle strip (vertices 0..3).
            const float2 positions[4] = { float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0), float2(1.0, 1.0) };
            // uv (0,0) at the top-left of the frame so buffer row 0 maps to the top of the screen.
            const float2 uvs[4] = { float2(0.0, 1.0), float2(1.0, 1.0), float2(0.0, 0.0), float2(1.0, 0.0) };
            VOut out;
            out.position = float4(positions[vid], 0.0, 1.0);
            out.uv = uvs[vid];
            return out;
        }

        static inline float4 dl_unpack(uint px) {
            // Premultiplied, byte order R,G,B,A (matches CGImage premultipliedLast / .abgr8888 target).
            float r = float(px & 0xFFu);
            float g = float((px >> 8) & 0xFFu);
            float b = float((px >> 16) & 0xFFu);
            float a = float((px >> 24) & 0xFFu);
            return float4(r, g, b, a) / 255.0;
        }

        fragment float4 dl_fragment(VOut in [[stage_in]],
                                    device const uint *pixels [[buffer(0)]],
                                    constant Params &p [[buffer(1)]]) {
            int w = int(p.width);
            int h = int(p.height);
            float2 coord = in.uv * float2(float(w), float(h)) - 0.5;
            float2 fr = fract(coord);
            int x0 = clamp(int(floor(coord.x)), 0, w - 1);
            int y0 = clamp(int(floor(coord.y)), 0, h - 1);
            int x1 = min(x0 + 1, w - 1);
            int y1 = min(y0 + 1, h - 1);
            uint stride = p.width;
            float4 c00 = dl_unpack(pixels[uint(y0) * stride + uint(x0)]);
            float4 c10 = dl_unpack(pixels[uint(y0) * stride + uint(x1)]);
            float4 c01 = dl_unpack(pixels[uint(y1) * stride + uint(x0)]);
            float4 c11 = dl_unpack(pixels[uint(y1) * stride + uint(x1)]);
            return mix(mix(c00, c10, fr.x), mix(c01, c11, fr.x), fr.y);
        }
        """

        do {
            let library = try metalDevice.makeLibrary(source: source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "dl_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "dl_fragment")

            // The software buffer is premultiplied; blend over the (transparent) clear color.
            if let attachment = descriptor.colorAttachments[0] {
                attachment.pixelFormat = mtkView.colorPixelFormat
                attachment.isBlendingEnabled = true
                attachment.rgbBlendOperation = .add
                attachment.alphaBlendOperation = .add
                attachment.sourceRGBBlendFactor = .one
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }

            self.renderPipelineState = try metalDevice.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("DotLottie: failed to build Metal render pipeline: \(error)")
        }
    }

    /// Caps the render resolution (longer side) so the core renders a smaller buffer that the
    /// GPU upscales to the full drawable — see `maxRenderDimension`.
    private static func cappedRenderSize(_ size: CGSize) -> CGSize {
        let longest = max(size.width, size.height)
        guard longest > maxRenderDimension, longest > 0 else { return size }
        let scale = maxRenderDimension / longest
        return CGSize(width: max(1, (size.width * scale).rounded(.down)),
                      height: max(1, (size.height * scale).rounded(.down)))
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
            // Render at a capped resolution (GPU upscales to the full drawable). `viewSize` keeps
            // the full drawable size so gesture/state-machine coordinate mapping stays correct.
            let renderSize = Coordinator.cappedRenderSize(size)
            self.parent.dotLottieViewModel.resize(width: Int(renderSize.width), height: Int(renderSize.height))
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
        
        guard !parent.dotLottieViewModel.error() else {
            return
        }

        // Ensure the GPU has finished reading the shared buffer before the core renders the next
        // frame into it. Every path after this point must balance the wait (signal or completion).
        inFlightSemaphore.wait()

        let now = CACurrentMediaTime()
        let dt = lastDrawTime == 0 ? Float(0) : Float((now - lastDrawTime) * 1000)
        lastDrawTime = now

        // Only redraw when the core produced a new frame (renders into the shared buffer).
        guard let frame = parent.dotLottieViewModel.tickMetalBuffer(dt: dt) else {
            inFlightSemaphore.signal()
            return
        }

        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let pipelineState = renderPipelineState,
              let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            inFlightSemaphore.signal()
            return
        }

        // The core already composites the configured background into the buffer, so clear the
        // drawable to transparent (matching the previous `isOpaque = false` behavior).
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            inFlightSemaphore.signal()
            return
        }

        // Read the core's render buffer directly in the shader — no extra texture or copy.
        var params = FrameParams(width: UInt32(frame.width), height: UInt32(frame.height))
        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBuffer(frame.buffer, offset: 0, index: 0)
        encoder.setFragmentBytes(&params, length: MemoryLayout<FrameParams>.stride, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inFlightSemaphore.signal()
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
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
#endif // os(macOS)
#endif // !os(watchOS)
