//
//  Example5_CustomConfiguration.swift
//  DotLottieIosTestApp
//
//  Custom configuration example
//

import DotLottie
import SwiftUI

struct Example5_CustomConfiguration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Example 5: Custom Configuration")
                .font(.subheadline)
                .foregroundColor(.secondary)

            DotLottiePlayerView {
                DotLottieAnimation(
                    fileName: "Flow",
                    config: AnimationConfig(
                        autoplay: true,
                        loop: true,
                        mode: .bounce,
                        speed: 2.0,
                        useFrameInterpolation: true
                    )
                )
            }
            .playing()
            .animationSpeed(2.0)
            .frame(height: 200)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text("• Mode: Bounce")
                    .font(.caption)
                Text("• Speed: 2x")
                    .font(.caption)
                Text("• Frame Interpolation: On")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}
