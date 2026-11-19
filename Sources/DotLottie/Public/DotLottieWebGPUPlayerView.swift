#if canImport(SwiftUI) && canImport(WgpuNative) && ((os(iOS) && !targetEnvironment(macCatalyst)) || os(macOS))
import SwiftUI

/// A SwiftUI view that renders a Lottie animation via WebGPU (Metal backend).
///
/// Wraps `DotLottieWebGPUView` as a `ViewRepresentable`. Use this in SwiftUI
/// hierarchies the same way you would use `DotLottieView` for the software renderer.
public struct DotLottieWebGPUPlayerView: ViewRepresentable {
    public typealias UIViewType = DotLottieWebGPUView

    private let config: Config
    private let fileName: String?
    private let animationData: String?
    private let webURL: String?
    private let bundle: Bundle
    private let onViewCreated: ((DotLottieWebGPUView) -> Void)?

    // MARK: - Init

    /// Load from a .json or .lottie file in the given bundle.
    ///
    /// - Parameter onViewCreated: Called once with the underlying
    ///   `DotLottieWebGPUView` shortly after it is created (dispatched async so it
    ///   is safe to assign to `@State`), so you can keep a reference for runtime
    ///   control (state-machine input, play/pause, etc.). For *initial*
    ///   state-machine setup prefer `Config(stateMachineId:)`, which starts the
    ///   machine after the animation has finished loading.
    public init(
        fileName: String,
        bundle: Bundle = .main,
        config: Config = Config(),
        onViewCreated: ((DotLottieWebGPUView) -> Void)? = nil
    ) {
        self.fileName = fileName
        self.animationData = nil
        self.webURL = nil
        self.bundle = bundle
        self.config = config
        self.onViewCreated = onViewCreated
    }

    /// Load from an in-memory Lottie JSON string.
    public init(
        animationData: String,
        config: Config = Config(),
        onViewCreated: ((DotLottieWebGPUView) -> Void)? = nil
    ) {
        self.fileName = nil
        self.animationData = animationData
        self.webURL = nil
        self.bundle = .main
        self.config = config
        self.onViewCreated = onViewCreated
    }

    /// Load a .json or .lottie animation from a remote URL.
    ///
    /// The file is fetched asynchronously and rendered once it finishes
    /// downloading. The extension is inferred from the URL (`.lottie` → dotLottie,
    /// otherwise Lottie JSON).
    public init(
        webURL: String,
        config: Config = Config(),
        onViewCreated: ((DotLottieWebGPUView) -> Void)? = nil
    ) {
        self.fileName = nil
        self.animationData = nil
        self.webURL = webURL
        self.bundle = .main
        self.config = config
        self.onViewCreated = onViewCreated
    }

    // MARK: - ViewRepresentable

    public func makeView(context: Context) -> DotLottieWebGPUView {
        let view = DotLottieWebGPUView(config: config)
        if let name = fileName {
            view.loadAnimation(fileName: name, bundle: bundle)
        } else if let data = animationData {
            view.loadAnimationData(data)
        } else if let webURL {
            view.loadAnimation(webURL: webURL)
        }
        // Deferred to the next runloop tick: `makeView` runs during SwiftUI's
        // update pass, so invoking the callback synchronously would let callers
        // mutate `@State` mid-update ("Modifying state during view update").
        if let onViewCreated {
            DispatchQueue.main.async { onViewCreated(view) }
        }
        return view
    }

    public func updateView(_ view: DotLottieWebGPUView, context: Context) {}
}

#endif
