//
//  Example2_WithControls.swift
//  DotLottieIosTestApp
//
//  Animation with playback controls
//

#if !os(tvOS)

    import SwiftUI
    import DotLottie

    struct Example2_WithControls: View {
        @State private var isPlaying = false
        @State private var loopMode: DotLottieLoopMode = .playOnce
        @State private var animationSpeed: Double = 1.0
        @State private var currentProgress: Double = 0.0

        let timer = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()

        let animation = DotLottieAnimation(
            fileName: "Flow",
            config: AnimationConfig(
                autoplay: false,
                loop: false,
                speed: 1.0
            )
        )

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Example 2: With Controls")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                DotLottiePlayerView(animation: animation)
                    .loopMode(loopMode)
                    .animationSpeed(animationSpeed)
                    .playbackMode(isPlaying ? .playing : .paused)
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)

                // Progress display
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress: \(String(format: "%.1f%%", currentProgress * 100))")
                        .font(.caption)

                    ProgressView(value: currentProgress)
                        .progressViewStyle(.linear)
                }

                // Control button
                Button(action: {
                    isPlaying.toggle()
                }) {
                    Label(
                        isPlaying ? "Pause" : "Play",
                        systemImage: isPlaying ? "pause.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // Speed control
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed: \(String(format: "%.2fx", animationSpeed))")
                        .font(.caption)

                    Slider(value: $animationSpeed, in: 0.25...3.0)
                }

                // Loop toggle
                Toggle(
                    "Loop Animation",
                    isOn: Binding(
                        get: { loopMode == .loop },
                        set: { loopMode = $0 ? .loop : .playOnce }
                    ))
            }
            .padding(.horizontal)
            .onReceive(timer) { _ in
                if isPlaying {
                    currentProgress = Double(animation.currentProgress())
                }
            }
        }
    }

#endif
