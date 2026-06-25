//
//  ContentView.swift
//  ExampleWatchOS Watch App
//
//  Created by Samuel Osborne on 25/06/2026.
//

import SwiftUI
import DotLottie

struct ContentView: View {
    let animation = DotLottieAnimation(
        webURL: "https://lottie.host/4db68bbd-31f6-4cd8-84eb-189de081159a/IGmMCqhzpt.lottie",
        config: AnimationConfig(autoplay: true, loop: true)
    )

    var body: some View {
        animation.view()
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
