//
//  Example11_ManyAnimations.swift
//  DotLottieIosTestApp
//
//  Many animations on screen at once, with a CPU/WebGPU toggle and a live metrics HUD.
//  Stresses the cost of many concurrent render contexts. Note that each WebGPU tile builds
//  its own wgpu device, whereas the CPU tiles share one Metal device — so this is where the
//  CPU renderer can overtake WebGPU as the tile count climbs.
//

import SwiftUI
import DotLottie

#if canImport(WgpuNative) && ((os(iOS) && !targetEnvironment(macCatalyst)) || os(macOS))

/// Looping animations from the bundle, cycled to fill the grid.
private let benchmarkAnimationPool = [
    "adding-guests",
    "confetti",
    "pigeon",
    "star-marked",
    "smiley-slider",
    "clipped-traffic-lights",
    "theming",
]

struct Example11_ManyAnimations: View {
    @State private var renderer: Renderer = .webGPU
    @State private var count: Int = 30
    @StateObject private var monitor = PerformanceMonitor()

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    private var names: [String] {
        (0..<count).map { benchmarkAnimationPool[$0 % benchmarkAnimationPool.count] }
    }

    var body: some View {
        VStack(spacing: 12) {
            RendererPicker(selection: $renderer)
                .padding(.horizontal)

            Stepper("Animations: \(count)", value: $count, in: 4...30, step: 2)
                .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                        AnimationTile(renderer: renderer, name: name)
                            .frame(height: 90)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                // Rebuild every tile when the renderer or count changes so old
                // render contexts are fully torn down.
                .id("\(renderer.rawValue)-\(count)")
            }

            MetricsOverlay(monitor: monitor)
                .padding(.bottom, 8)
        }
        .navigationTitle("Many Animations")
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }
}

/// A single grid cell rendering one animation with the selected renderer.
private struct AnimationTile: View {
    let renderer: Renderer
    let name: String

    var body: some View {
        switch renderer {
        case .cpu:
            CPUTile(name: name)
        case .webGPU:
            DotLottieWebGPUPlayerView(
                fileName: name,
                config: Config(autoplay: true, loopAnimation: true)
            )
        }
    }
}

/// CPU tile holds its `DotLottieAnimation` for the cell's lifetime so it isn't recreated on
/// every parent re-render.
private struct CPUTile: View {
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
