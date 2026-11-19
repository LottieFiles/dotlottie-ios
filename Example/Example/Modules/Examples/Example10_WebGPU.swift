//
//  Example10_WebGPU.swift
//  DotLottieIosTestApp
//
//  Single heavy ("4K") animation, full-screen, with a CPU/WebGPU toggle and a live metrics
//  HUD. Stresses the per-frame render cost so the two renderers can be compared head to head.
//

import SwiftUI
import DotLottie

#if canImport(WgpuNative) && ((os(iOS) && !targetEnvironment(macCatalyst)) || os(macOS))
struct Example10_StressTest: View {

    /// Preferred heavy animation: drop a `stress-4k.lottie` (or `.json`) into
    /// `Example/Example/Animations/` and add it to the app target. Until then the screen
    /// falls back to the bundled `coffee.lottie` so it's runnable out of the box.
    static let preferredName = "adding-guests"
    static let fallbackName = "coffee"

    @State private var renderer: Renderer = .webGPU
    @StateObject private var monitor = PerformanceMonitor()

    private static func exists(_ name: String) -> Bool {
        Bundle.main.url(forResource: name, withExtension: "lottie") != nil ||
        Bundle.main.url(forResource: name, withExtension: "json") != nil
    }

    /// The animation actually used: the preferred 4K asset if present, else the fallback.
    private var animationName: String? {
        if Self.exists(Self.preferredName) { return Self.preferredName }
        if Self.exists(Self.fallbackName) { return Self.fallbackName }
        return nil
    }

    private var usingFallback: Bool {
        animationName == Self.fallbackName
    }

    var body: some View {
        VStack(spacing: 12) {
            RendererPicker(selection: $renderer)
                .padding(.horizontal)

            ZStack {
                if let name = animationName {
                    rendererView(name: name)
                        // Force a full teardown/rebuild of the old renderer when toggling.
                        .id(renderer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    missingAssetView
                }
            }
            .background(Color.black.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            .overlay(alignment: .top) {
                MetricsOverlay(monitor: monitor)
                    .padding(.top, 8)
            }

            if usingFallback {
                Text("Showing bundled \(Self.fallbackName).lottie. For a real stress test, add \(Self.preferredName).lottie to Example/Example/Animations/.")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }

            Text("Toggle the renderer and watch the HUD. WebGPU should hold higher, steadier FPS at lower CPU on a heavy frame; the CPU renderer usually wins on memory.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .navigationTitle("CPU vs GPU backend renderer")
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    @ViewBuilder
    private func rendererView(name: String) -> some View {
        switch renderer {
        case .cpu:
            // Held in a child view via @StateObject so the per-second metric updates that
            // re-evaluate this view don't recreate the animation (which would reload it from
            // frame 0 and cause a visible restart).
            CPUStressView(name: name)
        case .webGPU:
            DotLottieWebGPUPlayerView(
                fileName: name,
                config: Config(autoplay: true, loopAnimation: true)
            )
        }
    }

    private var missingAssetView: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Add a heavy animation")
                .font(.headline)
            Text("Drop \(Self.preferredName).lottie into Example/Example/Animations/ and add it to the app target.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Holds the CPU `DotLottieAnimation` for the view's lifetime so it survives the parent's
/// per-second metric re-renders without reloading.
private struct CPUStressView: View {
    @StateObject private var animation: DotLottieAnimation

    init(name: String) {
        _animation = StateObject(wrappedValue: DotLottieAnimation(
            fileName: name,
            config: AnimationConfig(autoplay: true, loop: true)
        ))
    }

    var body: some View {
        DotLottiePlayerView(animation: animation)
            .looping()
    }
}
#endif
