//
//  AnimationInfoView.swift
//  DotLottieIosTestApp
//
//  Animation information display
//

import SwiftUI
import DotLottie

struct AnimationInfoView: View {
    let animation: DotLottieAnimation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Animation Info")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Total Frames: \(Int(animation.totalFrames()))")
                .font(.caption)
            
            // duration() is reported in milliseconds; convert to seconds for display.
            Text("Duration: \(String(format: "%.2fs", animation.duration() / 1000.0))")
                .font(.caption)
            
            Text("Framerate: \(animation.framerate) fps")
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

