//
//  ContentView_tvOS.swift
//

import DotLottie
import SwiftUI

#if os(tvOS)

    struct ContentView: View {
        var body: some View {
            NavigationView {
                List {
                    Section(header: Text("Examples")) {
                        NavigationLink("Simple Looping") {
                            Example1_SimpleLooping()
                        }
                        NavigationLink("Async Loading") {
                            Example4_AsyncLoading()
                        }
                        NavigationLink("Custom Configuration") {
                            Example5_CustomConfiguration()
                        }
                        NavigationLink("Multiple Animations") {
                            Example6_MultipleAnimations()
                        }
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
                        }
                    }
                }
                .navigationTitle("DotLottie Examples")
            }
        }
    }

    struct OriginalExampleView: View {
        var animation = DotLottieAnimation(
            fileName: "Flow",
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

    struct ContentView_tvOS_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }

#endif
