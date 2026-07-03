//
//  Example12_DynamicLayout.swift
//  DotLottieIosTestApp
//
//  Dynamically change the animation layout (fit + alignment) at runtime.
//

#if !os(tvOS)

import SwiftUI
import DotLottie

struct Example12_DynamicLayout: View {
    @State private var fit: Fit = .contain
    @State private var alignX: Float = 0.5
    @State private var alignY: Float = 0.5

    private let animation = DotLottieAnimation(
        fileName: "Flow 1",
        config: AnimationConfig(
            autoplay: true,
            loop: true,
            layout: Layout(fit: .contain, alignX: 0.5, alignY: 0.5)
        )
    )

    private let fits: [(Fit, String)] = [
        (.contain, "Contain"),
        (.cover, "Cover"),
        (.fill, "Fill"),
        (.fitWidth, "Fit Width"),
        (.fitHeight, "Fit Height"),
        (.none, "None"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Example 12: Dynamic Layout")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // A non-square frame makes the fit differences obvious.
            DotLottiePlayerView(animation: animation)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
                .cornerRadius(12)

            // Fit mode
            VStack(alignment: .leading, spacing: 4) {
                Picker("Fit", selection: $fit) {
                    ForEach(fits, id: \.0) { item in
                        Text(item.1).tag(item.0)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Alignment
            VStack(alignment: .leading, spacing: 4) {
                Text("Align X: \(String(format: "%.2f", alignX))")
                    .font(.caption)
                Slider(value: $alignX, in: 0...1)

                Text("Align Y: \(String(format: "%.2f", alignY))")
                    .font(.caption)
                Slider(value: $alignY, in: 0...1)
            }

            Text("Alignment only affects fits that leave empty space (e.g. Contain, Fit Width, Fit Height, None).")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .onChange(of: fit) { _ in applyLayout() }
        .onChange(of: alignX) { _ in applyLayout() }
        .onChange(of: alignY) { _ in applyLayout() }
    }

    private func applyLayout() {
        animation.setLayout(layout: Layout(fit: fit, alignX: alignX, alignY: alignY))
    }
}

struct Example12_DynamicLayout_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView { Example12_DynamicLayout() }
    }
}

#endif
