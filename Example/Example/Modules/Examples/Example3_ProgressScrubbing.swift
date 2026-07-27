//
//  Example3_ProgressScrubbing.swift
//  DotLottieIosTestApp
//
//  Progress control and scrubbing example
//

#if !os(tvOS)

    import SwiftUI
    import DotLottie

    struct Example3_ProgressScrubbing: View {
        @State private var isPlaying = false
        @State private var currentProgress: Double = 0.5
        @State private var isSliderBeingDragged = false
        @State private var loopMode: DotLottieLoopMode = .playOnce

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
                Text("Example 3: Progress Control & Scrubbing")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                DotLottiePlayerView(animation: animation)
                    .playbackMode(isPlaying ? .playing : .paused)
                    .currentProgress(isSliderBeingDragged ? currentProgress : nil)
                    .loopMode(loopMode)
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress: \(String(format: "%.1f%%", currentProgress * 100))")
                        .font(.caption)

                    Slider(
                        value: Binding(
                            get: { currentProgress },
                            set: { newValue in
                                currentProgress = newValue
                                _ = animation.setProgress(progress: Float(newValue))
                            }
                        ),
                        in: 0...1,
                        onEditingChanged: { editing in
                            isSliderBeingDragged = editing
                        }
                    )
                }

                // Control button
                Button(action: {
                    isPlaying.toggle()
                    if isPlaying {
                        _ = animation.setProgress(progress: Float(currentProgress))
                    }
                }) {
                    Label(
                        isPlaying ? "Pause" : "Play",
                        systemImage: isPlaying ? "pause.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

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
                if isPlaying && !isSliderBeingDragged {
                    currentProgress = Double(animation.currentProgress())
                }
            }
        }
    }

#endif
