//
//  ContentView.swift
//  DotLottieIosTestApp
//
//  Created by Sam on 10/11/2023.
//

import SwiftUI
import DotLottie

#if !os(tvOS)

struct ContentView: View {
    var body: some View {
        DotLottieAnimation(
            fileName: "pigeon",
            config: AnimationConfig(
                autoplay: true,
                loop: true
            )
        ).view()
    }
    
    @ViewBuilder
    private var exampleList: some View {
        List {
            Section(header: Text("Original DotLottie Examples")) {
                NavigationLink("Basic Example") {
                    OriginalExampleView()
                }
            }
            
            Section(header: Text("New LottieAnimationView-Style API")) {
#if canImport(UIKit)
                NavigationLink("UIKit Example (DotLottiePlayerUIView)") {
                    UIKitExampleViewWrapper()
                }
#endif
                    
                    NavigationLink("SwiftUI Example (DotLottiePlayerView)") {
                        SwiftUIExampleView()
                    }
                }
                
                Section(header: Text("URL Loading")) {
                    NavigationLink("Load from URL") {
                        ScrollView {
                            VStack(spacing: 24) {
                                Text("URL Loading")
                                    .font(.headline)
                                    .padding(.top)
                                Example8_URLLoading()
                                Spacer(minLength: 24)
                            }
                        }
                        .navigationTitle("URL Loading")
                    }
                }

                Section(header: Text("Layout")) {
                    NavigationLink("Dynamic Layout (Fit & Alignment)") {
                        ScrollView { Example12_DynamicLayout() }
                            .navigationTitle("Dynamic Layout")
                    }
                }

                Section(header: Text("State Machine & Interactivity")) {
                    NavigationLink("SwiftUI State Machine Example") {
                        Example7_StateMachine()
                    }
                    
#if canImport(UIKit)
                NavigationLink("UIKit State Machine Example") {
                    UIKitStateMachineViewWrapper()
                }
#endif
            }
            
            
#if canImport(SwiftUI) && ((os(iOS) && !targetEnvironment(macCatalyst)) || (os(macOS) && !targetEnvironment(macCatalyst)))
            Section(header: Text("Performance & Benchmarking")) {
                NavigationLink("Test (CPU vs WebGPU)") {
                    Example10_StressTest()
                }

                NavigationLink("Many Animations (CPU vs WebGPU)") {
                    Example11_ManyAnimations()
                }
            }
#endif
            
            Section(header: Text("About")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DotLottie iOS Test App")
                        .font(.headline)
                    
                    Text("This app demonstrates different ways to use dotlottie animations:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• Original DotLottie API")
                        .font(.caption)
                    
#if canImport(UIKit)
                    Text("• UIKit: DotLottiePlayerUIView (like LottieAnimationView)")
                        .font(.caption)
#else
                    Text("• AppKit: DotLottiePlayerUIView (like LottieAnimationView)")
                        .font(.caption)
#endif
                    
                    Text("• SwiftUI: DotLottiePlayerView (like LottieView)")
                        .font(.caption)
                    
#if canImport(UIKit)
                    Text("• State Machine examples with touch interaction")
                        .font(.caption)
#else
                    Text("• State Machine examples with mouse interaction")
                        .font(.caption)
#endif
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("DotLottie Examples")
    }
}

// MARK: - Original Example

struct OriginalExampleView: View {
    var animation = DotLottieAnimation(
        fileName: "Flow 1",
        config: AnimationConfig(
            autoplay: false,
            loop: true
        )
    )
    
    var body: some View {
        VStack {
            animation.view()
                .padding()
            
            Button {
                if animation.isPlaying() {
                    _ = animation.pause()
                } else {
                    _ = animation.setFrame(frame: 0)
                    _ = animation.play()
                }
            } label: {
                Text("Toggle Play")
            }
            .buttonStyle(.bordered)
            .padding()
        }
        .navigationTitle("Original API")
    }
}

// MARK: - UIKit Wrappers

#if canImport(UIKit)
struct UIKitExampleViewWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitExampleViewController {
        return UIKitExampleViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIKitExampleViewController, context: Context) {
        // No updates needed
    }
}

struct UIKitStateMachineViewWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitStateMachineViewController {
        return UIKitStateMachineViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIKitStateMachineViewController, context: Context) {
        // No updates needed
    }
}

#endif

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

#endif
