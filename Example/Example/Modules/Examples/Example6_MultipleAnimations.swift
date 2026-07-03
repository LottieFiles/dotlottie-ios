//
//  Example6_MultipleAnimations.swift
//  DotLottieIosTestApp
//
//  Multiple animations with memory management
//

import SwiftUI
import DotLottie

/// Wrapper to hold an animation that can be loaded/unloaded
class AnimationHolder: ObservableObject {
    let name: String
    @Published var animation: DotLottieAnimation?
    @Published var isVisible = false
    
    init(name: String) {
        self.name = name
    }
    
    func load() {
        guard animation == nil else { return }
        print("📦 Loading animation: \(name)")
        animation = DotLottieAnimation(
            fileName: name,
            config: AnimationConfig(
                autoplay: true,
                loop: true,
                speed: 1.0
            )
        )
    }
    
    func unload() {
        guard animation != nil else { return }
        print("🗑️ Unloading animation: \(name)")
        _ = animation?.stop()
        animation = nil
    }
}

struct Example6_MultipleAnimations: View {
    @State private var animationHolders: [AnimationHolder] = []
    @State private var showStats = false
    
    let availableAnimations = [
        "Flow 1",
        "adding-guests",
        "analytics",
        "button",
        "click-button",
        "clipped-traffic-lights",
        "hold-button",
        "idle",
        "loader",
        "loadingAnimation",
        "pigeon",
        "smiley-slider",
        "star-marked",
        "sync-to-cursor",
        "theming",
        "toggle"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Example 6: Multiple Animations (Memory Management)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Text("Animations load when visible and unload when scrolled away")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Toggle("Show Stats", isOn: $showStats)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 16) {
                    ForEach(animationHolders.indices, id: \.self) { index in
                        AnimationCard(
                            holder: animationHolders[index],
                            showStats: showStats
                        )
                        .onAppear {
                            animationHolders[index].isVisible = true
                            animationHolders[index].load()
                        }
                        .onDisappear {
                            animationHolders[index].isVisible = false
                            // Unload after a small delay to handle quick scrolls
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if !animationHolders[index].isVisible {
                                    animationHolders[index].unload()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 280)
            
            if showStats {
                StatsView(holders: animationHolders)
                    .padding(.horizontal)
            }
        }
        .onAppear {
            if animationHolders.isEmpty {
                animationHolders = availableAnimations.map { AnimationHolder(name: $0) }
            }
        }
        .onDisappear {
            // Clean up all animations when view disappears
            animationHolders.forEach { $0.unload() }
        }
    }
}

struct AnimationCard: View {
    @ObservedObject var holder: AnimationHolder
    let showStats: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let animation = holder.animation {
                    if animation.isLoaded() {
                        DotLottiePlayerView(animation: animation)
                            .looping()
                            .frame(width: 200, height: 200)
                    } else {
                        LoadingPlaceholder()
                    }
                } else {
                    UnloadedPlaceholder()
                }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            VStack(spacing: 4) {
                Text(holder.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if showStats {
                    HStack(spacing: 8) {
                        StatusIndicator(
                            isOn: holder.animation != nil,
                            label: "Loaded"
                        )
                        StatusIndicator(
                            isOn: holder.isVisible,
                            label: "Visible"
                        )
                    }
                    .font(.caption2)
                }
            }
        }
        .frame(width: 200)
    }
}

struct LoadingPlaceholder: View {
    var body: some View {
        VStack {
            ProgressView()
            Text("Loading...")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 200, height: 200)
    }
}

struct UnloadedPlaceholder: View {
    var body: some View {
        VStack {
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("Not Loaded")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 200, height: 200)
    }
}

struct StatusIndicator: View {
    let isOn: Bool
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isOn ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            Text(label)
        }
    }
}

struct StatsView: View {
    let holders: [AnimationHolder]
    
    var loadedCount: Int {
        holders.filter { $0.animation != nil }.count
    }
    
    var visibleCount: Int {
        holders.filter { $0.isVisible }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Memory Stats")
                .font(.caption)
                .fontWeight(.semibold)
            
            HStack {
                StatItem(label: "Total", value: "\(holders.count)")
                Divider().frame(height: 20)
                StatItem(label: "Loaded", value: "\(loadedCount)", color: loadedCount > 0 ? .green : .gray)
                Divider().frame(height: 20)
                StatItem(label: "Visible", value: "\(visibleCount)", color: visibleCount > 0 ? .blue : .gray)
                Divider().frame(height: 20)
                StatItem(label: "Unloaded", value: "\(holders.count - loadedCount)", color: .orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

