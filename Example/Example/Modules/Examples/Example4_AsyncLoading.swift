//
//  Example4_AsyncLoading.swift
//  DotLottieIosTestApp
//
//  Async loading with placeholder example
//

import DotLottie
import SwiftUI

struct Example4_AsyncLoading: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Example 4: Async Loading")
                .font(.subheadline)
                .foregroundColor(.secondary)

            DotLottiePlayerView {
                // Simulate async loading
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
                return DotLottieAnimation(
                    fileName: "Flow",
                    config: AnimationConfig(autoplay: true, loop: true)
                )
            } placeholder: {
                VStack {
                    ProgressView()
                    Text("Loading animation...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 200)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Text("Demonstrates async loading with a 1-second delay")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}
