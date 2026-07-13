//
//  DotLottieView.swift
//
//
//  Created by Sam on 25/10/2023.
//
//

#if !os(watchOS)
import Metal
import MetalKit
import CoreImage
import SwiftUI

// SwiftUI animation view
public struct DotLottieView: ViewRepresentable, DotLottie {
    public typealias UIViewType = MTKView
    
#if os(macOS)
    private var mtkView: MTKView = InteractiveMTKView()
#else
    private var mtkView: MTKView = MTKView()
#endif
    
#if os(iOS)
    private let gestureManager = GestureManager()
#endif
    
    @ObservedObject internal var dotLottieViewModel: DotLottieAnimation
    @ObservedObject internal var playerState: Player
    
    public init(dotLottie: DotLottieAnimation) {
        self.dotLottieViewModel = dotLottie
        self.playerState = dotLottie.player
    }
    
    public func makeCoordinator() -> Coordinator {
#if os(iOS)
        return Coordinator(self, mtkView: self.mtkView)
#elseif os(macOS)
        return Coordinator(self, mtkView: self.mtkView)
#else
        return Coordinator(self, mtkView: self.mtkView)
#endif
    }
    
    public func makeView(context: Context) -> MTKView {
#if os(iOS)
        self.mtkView.isOpaque = false
#elseif os(macOS)
        self.mtkView.layer?.isOpaque = false
        self.mtkView.layer?.backgroundColor = NSColor.clear.cgColor
        // Ensure the view can become first responder and receive mouse events
        if let interactiveView = self.mtkView as? InteractiveMTKView {
            interactiveView.gestureCoordinator = context.coordinator
            interactiveView.updateTrackingAreas()
        }
#endif
        
        self.mtkView.framebufferOnly = false
        
        self.mtkView.delegate = context.coordinator
        
        self.mtkView.preferredFramesPerSecond = self.dotLottieViewModel.framerate
        
        self.mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        self.mtkView.isPaused = false
        
        self.mtkView.enableSetNeedsDisplay = true
        
#if os(iOS)
        // Gesture management
        gestureManager.cancelsTouchesInView = false
        gestureManager.delegate = context.coordinator
        gestureManager.gestureManagerDelegate = context.coordinator
        self.mtkView.addGestureRecognizer(gestureManager)
#endif
        
        return mtkView
    }
    
    public func updateView(_ uiView: MTKView, context: Context) {
        // All animations will be paused if this is not set to false here.
        uiView.isPaused = false
        
        if self.dotLottieViewModel.framerate != 30 {
            uiView.preferredFramesPerSecond = self.dotLottieViewModel.framerate
        }
        
#if os(macOS)
        // Update tracking areas when view updates (e.g., size changes)
        if let interactiveView = uiView as? InteractiveMTKView {
            interactiveView.updateTrackingAreas()
        }
#endif
    }
    
    public func subscribe(observer: Observer) {
        self.dotLottieViewModel.subscribe(observer: observer)
    }
}

#else // os(watchOS)

import SwiftUI
import CoreGraphics

public struct DotLottieView: View, DotLottie {
    @ObservedObject public var dotLottieViewModel: DotLottieAnimation
    @ObservedObject internal var playerState: Player
    @State private var currentImage: CGImage?
    @State private var viewSize: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var lastTickTime: CFTimeInterval = 0
    @Environment(\.displayScale) private var displayScale: CGFloat
    
    public init(dotLottie: DotLottieAnimation) {
        self.dotLottieViewModel = dotLottie
        self.playerState = dotLottie.player
    }
    
    /// Resize the animation buffer to physical pixels and record the point-based view size.
    private func updateViewSize(_ size: CGSize) {
        viewSize = size
        let physW = Int(size.width * displayScale)
        let physH = Int(size.height * displayScale)
        if physW > 0 && physH > 0 {
            dotLottieViewModel.resize(width: physW, height: physH)
        }
    }

    /// Returns the rect the animation actually occupies inside the view after aspect-fit
    /// letterboxing — equivalent to AVMakeRect(aspectRatio:insideRect:).
    /// Taps outside this rect fall in the letterbox and should not be forwarded to the
    /// state machine; taps inside are remapped relative to this rect's origin.
    private func imageRect(in size: CGSize) -> CGRect {
        let animWidth = CGFloat(dotLottieViewModel.animationModel.width)
        let animHeight = CGFloat(dotLottieViewModel.animationModel.height)
        guard animWidth > 0, animHeight > 0, size.width > 0, size.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        let viewAspect = size.width / size.height
        let animAspect = animWidth / animHeight

        let renderedSize: CGSize
        if animAspect > viewAspect {
            // Wider than view — letterboxed top/bottom
            let w = size.width
            let h = w / animAspect
            renderedSize = CGSize(width: w, height: h)
        } else {
            // Taller than view — letterboxed left/right
            let h = size.height
            let w = h * animAspect
            renderedSize = CGSize(width: w, height: h)
        }

        let origin = CGPoint(
            x: (size.width - renderedSize.width) / 2,
            y: (size.height - renderedSize.height) / 2
        )
        return CGRect(origin: origin, size: renderedSize)
    }

    /// Map a SwiftUI touch location (points) to animation buffer coordinates (physical pixels),
    /// accounting for aspect-fit letterboxing. Taps in the letterbox area are clamped to the
    /// nearest edge of the animation rect rather than being forwarded as out-of-bounds coordinates.
    private func mapCoordinates(location: CGPoint) -> CGPoint {
        let rect = imageRect(in: viewSize)
        let animWidth = CGFloat(dotLottieViewModel.animationModel.width)
        let animHeight = CGFloat(dotLottieViewModel.animationModel.height)
        guard rect.width > 0, rect.height > 0, animWidth > 0, animHeight > 0 else {
            return location
        }
        // Offset relative to image rect origin, clamped to its bounds
        let x = min(max(location.x - rect.origin.x, 0), rect.width)
        let y = min(max(location.y - rect.origin.y, 0), rect.height)
        // Scale from view points to animation buffer coordinates
        return CGPoint(
            x: x / rect.width * animWidth,
            y: y / rect.height * animHeight
        )
    }

    private func tickFrame() -> CGImage? {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = lastTickTime == 0 ? Float(0) : Float((now - lastTickTime) * 1000)
        lastTickTime = now
        return dotLottieViewModel.tick(dt: dt)
    }

    private struct StateMachineGestureModifier<G: Gesture>: ViewModifier {
        let gesture: G
        let isActive: Bool

        func body(content: Content) -> some View {
            if isActive {
                content.gesture(gesture)
            } else {
                content
            }
        }
    }
    
    // MARK: - Body

    public var body: some View {
        if #available(watchOS 8.0, *) {
            TimelineView(.animation(minimumInterval: 1.0 / Double(max(1, dotLottieViewModel.framerate)))) { timeline in
                GeometryReader { geometry in
                    frameContent(geometry: geometry)
                        .onChange(of: timeline.date) { _ in
                            if let frame = tickFrame() {
                                currentImage = frame
                            }
                        }
                }
                .modifier(StateMachineGestureModifier(
                    gesture: animationGesture,
                    isActive: dotLottieViewModel.config.stateMachineId != nil
                ))            }
        } else {
            GeometryReader { geometry in
                frameContent(geometry: geometry)
            }
            .modifier(StateMachineGestureModifier(
                gesture: animationGesture,
                isActive: dotLottieViewModel.config.stateMachineId != nil
            ))
            .onReceive(
                Timer.publish(every: 1.0 / Double(max(1, dotLottieViewModel.framerate)), on: .main, in: .common).autoconnect()
            ) { _ in
                if let frame = tickFrame() {
                    currentImage = frame
                }
            }
        }
    }

    // MARK: - Subviews

    private func frameContent(geometry: GeometryProxy) -> some View {
        Group {
            if let image = currentImage {
                Image(decorative: image, scale: displayScale)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                Color.clear
            }
        }
        .onAppear {
            updateViewSize(geometry.size)
            if let frame = tickFrame() {
                currentImage = frame
            }
        }
        .onChange(of: geometry.size) { newSize in
            updateViewSize(newSize)
        }
    }

    // MARK: - Gestures

    private var animationGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    let mapped = mapCoordinates(location: value.startLocation)
                    dotLottieViewModel.stateMachinePostEvent(.pointerDown(x: Float(mapped.x), y: Float(mapped.y)))
                }
                let mapped = mapCoordinates(location: value.location)
                dotLottieViewModel.stateMachinePostEvent(.pointerMove(x: Float(mapped.x), y: Float(mapped.y)))
            }
            .onEnded { value in
                isDragging = false
                let mapped = mapCoordinates(location: value.location)
                dotLottieViewModel.stateMachinePostEvent(.pointerUp(x: Float(mapped.x), y: Float(mapped.y)))
                let dx = value.location.x - value.startLocation.x
                let dy = value.location.y - value.startLocation.y
                if (dx * dx + dy * dy) < 100 {
                    let mappedStart = mapCoordinates(location: value.startLocation)
                    dotLottieViewModel.stateMachinePostEvent(.click(x: Float(mappedStart.x), y: Float(mappedStart.y)))
                }
            }
    }

    // MARK: - Public API

    public func subscribe(observer: Observer) {
        dotLottieViewModel.subscribe(observer: observer)
    }
}

#endif // !os(watchOS)
