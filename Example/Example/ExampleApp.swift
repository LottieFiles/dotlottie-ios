//
//  ExampleApp.swift
//  Example
//
//  Created by Sam on 10/11/2023.
//

import SwiftUI
#if os(iOS)
import AVFoundation
#endif

@main
struct ExampleApp: App {
    init() {
        #if os(iOS)
        // Let animations with audio layers play even when the ring/silent switch is on.
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
