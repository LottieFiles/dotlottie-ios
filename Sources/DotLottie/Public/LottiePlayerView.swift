#if canImport(SwiftUI) && !os(watchOS)
import SwiftUI

// MARK: - DotLottiePlayerView

@available(iOS 14.0, macOS 11.0, tvOS 14.0, *)
public struct DotLottiePlayerView<Placeholder: View>: View {
    
    // MARK: - Lifecycle
    
    /// Creates a `DotLottiePlayerView` with a dotlottie animation
    public init(animation: DotLottieAnimation?) where Placeholder == EmptyView {
        localAnimation = animation
        placeholder = nil
    }
    
    /// Creates a `DotLottiePlayerView` that asynchronously loads an animation
    /// The `loadAnimation` closure is called exactly once in `onAppear`.
    public init(_ loadAnimation: @escaping () async throws -> DotLottieAnimation?) where Placeholder == EmptyView {
        self.init(loadAnimation, placeholder: EmptyView.init)
    }
    
    /// Creates a `DotLottiePlayerView` that asynchronously loads an animation
    /// While loading, the `placeholder` view is shown
    public init(
        _ loadAnimation: @escaping () async throws -> DotLottieAnimation?,
        @ViewBuilder placeholder: @escaping () -> Placeholder)
    {
        localAnimation = nil
        self.loadAnimation = loadAnimation
        self.placeholder = placeholder
    }
    
    // MARK: - Public
    
    public var body: some View {
        ZStack {
            if let displayAnimation = displayAnimation {
                DotLottiePlayerViewRepresentable(
                    animation: displayAnimation,
                    config: config,
                    loopMode: loopMode,
                    animationSpeed: animationSpeed,
                    currentProgress: currentProgress,
                    currentFrame: currentFrame,
                    playbackMode: playbackMode,
                    configurations: configurations,
                    animationDidLoad: animationDidLoad
                )
            } else {
                placeholder?()
            }
        }
        .onAppear {
            loadAnimationIfNecessary()
        }
        .onChange(of: reloadAnimationTrigger) { _ in
            reloadAnimationTriggerDidChange()
        }
    }
    
    /// Returns a copy of this view with the given configuration
    public func configure(_ configure: @escaping (DotLottiePlayerUIView) -> Void) -> Self {
        var copy = self
        copy.configurations.append(configure)
        return copy
    }
    
    /// Returns a copy of this view that loops its animation
    public func looping() -> Self {
        var copy = self
        copy.loopMode = .loop
        copy.playbackMode = .playing
        return copy
    }
    
    /// Returns a copy of this view playing once
    public func playing() -> Self {
        var copy = self
        copy.loopMode = .playOnce
        copy.playbackMode = .playing
        return copy
    }
    
    /// Returns a copy of this view with the given loop mode
    public func loopMode(_ loopMode: DotLottieLoopMode) -> Self {
        var copy = self
        copy.loopMode = loopMode
        return copy
    }
    
    /// Returns a copy of this view paused at the current frame
    public func paused() -> Self {
        var copy = self
        copy.playbackMode = .paused
        return copy
    }
    
    /// Returns a copy of this view with the given playback mode
    public func playbackMode(_ playbackMode: DotLottiePlaybackMode) -> Self {
        var copy = self
        copy.playbackMode = playbackMode
        return copy
    }
    
    /// Returns a copy of this view with the given animation speed
    public func animationSpeed(_ speed: Double) -> Self {
        var copy = self
        copy.animationSpeed = speed
        return copy
    }
    
    /// Returns a copy of this view with the given configuration
    public func configuration(_ config: AnimationConfig) -> Self {
        var copy = self
        copy.config = config
        return copy
    }
    
    /// Returns a copy of this view with a closure called when animation loads
    public func animationDidLoad(_ callback: @escaping (DotLottieAnimation?) -> Void) -> Self {
        var copy = self
        copy.animationDidLoad = callback
        return copy
    }
    
    /// Returns a copy of this view at the given progress (0.0 to 1.0)
    public func currentProgress(_ progress: Double?) -> Self {
        guard let progress else { return self }
        var copy = self
        copy.currentProgress = progress
        copy.playbackMode = .paused
        return copy
    }
    
    /// Returns a copy of this view at the given frame
    public func currentFrame(_ frame: Double?) -> Self {
        guard let frame else { return self }
        var copy = self
        copy.currentFrame = frame
        copy.playbackMode = .paused
        return copy
    }
    
    /// Returns a copy of this view with the given mode
    public func mode(_ mode: Mode) -> Self {
        var copy = self
        copy.config.mode = mode
        return copy
    }
    
    /// Returns a copy of this view with frame interpolation enabled/disabled
    public func useFrameInterpolation(_ enabled: Bool) -> Self {
        var copy = self
        copy.config.useFrameInterpolation = enabled
        return copy
    }
    
    /// Returns a copy of this view with the given segments
    public func segments(_ segments: (Float, Float)?) -> Self {
        var copy = self
        copy.config.segments = segments
        return copy
    }
    
    /// Returns a copy of this view that triggers reload when the value changes
    public func reloadAnimationTrigger<T: Hashable>(_ value: T, showPlaceholder: Bool = true) -> Self {
        var copy = self
        copy.reloadAnimationTrigger = AnyHashable(value)
        copy.showPlaceholderWhileReloading = showPlaceholder
        return copy
    }
    
    // MARK: - Private
    
    @State private var remoteAnimation: DotLottieAnimation?
    
    private let localAnimation: DotLottieAnimation?
    private var loadAnimation: (() async throws -> DotLottieAnimation?)?
    private var animationDidLoad: ((DotLottieAnimation?) -> Void)?
    private var config = AnimationConfig()
    private var loopMode: DotLottieLoopMode = .playOnce
    private var animationSpeed: Double = 1.0
    private var currentProgress: Double?
    private var currentFrame: Double?
    private var playbackMode: DotLottiePlaybackMode = .paused
    private var reloadAnimationTrigger: AnyHashable?
    private var showPlaceholderWhileReloading = false
    private var configurations: [(DotLottiePlayerUIView) -> Void] = []
    private let placeholder: (() -> Placeholder)?
    
    private var displayAnimation: DotLottieAnimation? {
        localAnimation ?? remoteAnimation
    }
    
    private func loadAnimationIfNecessary() {
        guard let loadAnimation else { return }
        
        Task {
            do {
                let animation = try await loadAnimation()
                await MainActor.run {
                    remoteAnimation = animation
                }
            } catch {
                print("Failed to load dotlottie animation: \(error)")
            }
        }
    }
    
    private func reloadAnimationTriggerDidChange() {
        guard loadAnimation != nil else { return }
        
        if showPlaceholderWhileReloading {
            remoteAnimation = nil
        }
        
        loadAnimationIfNecessary()
    }
}

// MARK: - DotLottiePlaybackMode

public enum DotLottiePlaybackMode {
    case playing
    case paused
}

// MARK: - DotLottiePlayerViewRepresentable

@available(iOS 14.0, macOS 11.0, tvOS 14.0, *)
private struct DotLottiePlayerViewRepresentable: PlatformViewRepresentable {
    
    #if canImport(UIKit)
    typealias PlatformViewType = UIView
    #else
    typealias PlatformViewType = NSView
    #endif
    let animation: DotLottieAnimation
    let config: AnimationConfig
    let loopMode: DotLottieLoopMode
    let animationSpeed: Double
    let currentProgress: Double?
    let currentFrame: Double?
    let playbackMode: DotLottiePlaybackMode
    let configurations: [(DotLottiePlayerUIView) -> Void]
    let animationDidLoad: ((DotLottieAnimation?) -> Void)?

    final class Coordinator {
        private var hasFired = false
        private var loadedAnimation: DotLottieAnimation?

        func animationDidLoad(
            _ animation: DotLottieAnimation?,
            callback: ((DotLottieAnimation?) -> Void)?)
        {
            // Fire once per loaded animation; re-fire if a different animation loads (reload).
            guard !hasFired || loadedAnimation !== animation else { return }
            hasFired = true
            loadedAnimation = animation
            callback?(animation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    #if canImport(UIKit)
    func makeUIView(context: Context) -> PlatformViewType {
        makePlatformView(context: context)
    }
    
    func updateUIView(_ uiView: PlatformViewType, context: Context) {
        updatePlatformView(uiView, context: context)
    }
    #else
    func makeNSView(context: Context) -> PlatformViewType {
        makePlatformView(context: context)
    }
    
    func updateNSView(_ nsView: PlatformViewType, context: Context) {
        updatePlatformView(nsView, context: context)
    }
    #endif
    
    private func makePlatformView(context: Context) -> PlatformViewType {
        // Create container to prevent layout issues
        #if canImport(UIKit)
        let container = UIView()
        #else
        let container = NSView()
        #endif
        
        let view = DotLottiePlayerUIView(dotLottieAnimation: animation, config: config)
        view.loopMode = loopMode
        view.animationSpeed = CGFloat(animationSpeed)

        if animationDidLoad != nil {
            let coordinator = context.coordinator
            view.animationLoaded = { [weak coordinator] _, animation in
                coordinator?.animationDidLoad(animation, callback: animationDidLoad)
            }
        }
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Set content hugging and compression resistance to prevent size issues
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        container.addSubview(view)
        
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // Apply configurations
        configurations.forEach { $0(view) }
        
        #if canImport(UIKit)
        // Tag the view so we can find it in updatePlatformView (iOS only)
        view.tag = 12345
        #endif
        
        return container
    }
    
    private func updatePlatformView(_ platformView: PlatformViewType, context: Context) {
        // Find the DotLottiePlayerUIView inside the container
        #if canImport(UIKit)
        guard let view = platformView.viewWithTag(12345) as? DotLottiePlayerUIView else { return }
        #else
        // On macOS, get the first subview (which is our DotLottiePlayerUIView)
        guard let view = platformView.subviews.first as? DotLottiePlayerUIView else { return }
        #endif
        // Prevent layout loops by checking if values actually changed
        
        // Update animation if changed
        if view.dotLottieAnimation !== animation {
            view.dotLottieAnimation = animation
        }
        
        // Update loop mode only if different
        if view.loopMode != loopMode {
            view.loopMode = loopMode
        }
        
        // Update speed only if different
        let currentSpeed = view.animationSpeed
        let newSpeed = CGFloat(animationSpeed)
        if abs(currentSpeed - newSpeed) > 0.01 {
            view.animationSpeed = newSpeed
        }
        
        // Update current progress or frame only if provided
        if let currentProgress {
            let current = view.currentProgress
            let new = CGFloat(currentProgress)
            if abs(current - new) > 0.001 {
                view.currentProgress = new
            }
        } else if let currentFrame {
            let current = view.currentFrame
            let new = CGFloat(currentFrame)
            if abs(current - new) > 0.1 {
                view.currentFrame = new
            }
        }
        
        // Apply playback mode (skip when state machine is managing playback)
        if !animation.isStateMachineRunning() {
            switch playbackMode {
            case .playing:
                if !view.isAnimationPlaying {
                    view.play()
                }
            case .paused:
                if view.isAnimationPlaying {
                    view.pause()
                }
            }
        }
        
        // Apply configurations
        configurations.forEach { $0(view) }
    }
}

// MARK: - Platform Abstraction

#if canImport(UIKit)
private protocol PlatformViewRepresentable: UIViewRepresentable {}
#else
private protocol PlatformViewRepresentable: NSViewRepresentable {}
#endif


#endif

