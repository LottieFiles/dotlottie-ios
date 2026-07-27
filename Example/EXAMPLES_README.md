# DotLottie iOS Examples

This test app demonstrates three different ways to use dotlottie animations in iOS applications.

## Examples Included

### 1. Original DotLottie API
**File:** `ContentView.swift` (OriginalExampleView)

The original API where you create a `DotLottieAnimation` and call methods directly on it:

```swift
let animation = DotLottieAnimation(
    fileName: "Flow",
    config: AnimationConfig(autoplay: false, loop: true)
)

// Use in SwiftUI
animation.view()

// Control playback
animation.play()
animation.pause()
animation.setFrame(frame: 0)
```

### 2. UIKit Example - DotLottiePlayerUIView
**File:** `UIKitExampleViewController.swift`

A UIKit view similar to `LottieAnimationView` from lottie-ios. This provides a familiar API for UIKit developers:

```swift
// Initialize
let playerView = DotLottiePlayerUIView(
    name: "Flow",
    bundle: .main,
    config: AnimationConfig()
) { view, error in
    print("Animation loaded!")
}

// Configure
playerView.loopMode = .loop
playerView.animationSpeed = 2.0

// Control playback
playerView.play()
playerView.pause()
playerView.stop()

// Access properties
let progress = playerView.currentProgress
let frame = playerView.currentFrame
let totalFrames = playerView.totalFrames
```

**Features Demonstrated:**
- ✅ Loading animations from bundle
- ✅ Play/Pause/Stop controls
- ✅ Progress slider for scrubbing
- ✅ Speed control (0.25x - 3x)
- ✅ Loop mode toggle
- ✅ Real-time status updates
- ✅ Frame and progress tracking

### 3. SwiftUI Example - DotLottiePlayerView
**File:** `SwiftUIExampleView.swift`

A SwiftUI view similar to `LottieView` from lottie-ios. This uses SwiftUI's declarative syntax with modifier chains:

```swift
// Simple looping animation
DotLottiePlayerView(animation: animation)
    .looping()
    .animationSpeed(2.0)
    .frame(height: 200)

// With progress control
DotLottiePlayerView(animation: animation)
    .currentProgress(0.5)
    .playbackMode(.paused)

// Async loading with placeholder
DotLottiePlayerView {
    try await DotLottieAnimation(webURL: url, config: config)
} placeholder: {
    ProgressView()
}
```

**Examples Demonstrated:**

1. **Simple Looping** - Basic auto-playing looped animation
2. **With Controls** - Play/pause buttons, speed slider, loop toggle
3. **Progress Control** - Scrub through animation with slider
4. **Async Loading** - Load animation asynchronously with loading indicator
5. **Custom Configuration** - Advanced settings (mode, frame interpolation)

**Available Modifiers:**
- `.looping()` - Loop the animation
- `.playing()` - Play once
- `.paused()` - Pause at current frame
- `.playbackMode(_:)` - Set playback mode
- `.loopMode(_:)` - Set loop mode
- `.animationSpeed(_:)` - Set playback speed
- `.currentProgress(_:)` - Set progress (0.0-1.0)
- `.currentFrame(_:)` - Set specific frame
- `.mode(_:)` - Set playback mode (forward, reverse, bounce)
- `.useFrameInterpolation(_:)` - Enable/disable frame interpolation
- `.segments(_:)` - Play specific segment
- `.configuration(_:)` - Set animation configuration
- `.animationDidLoad(_:)` - Callback when animation loads
- `.reloadAnimationTrigger(_:)` - Trigger animation reload

## Initializer Options

### DotLottiePlayerUIView (UIKit)

```swift
// From bundle
DotLottiePlayerUIView(name: "animation", bundle: .main, config: config)

// From file path
DotLottiePlayerUIView(filePath: "/path/to/file.lottie", config: config)

// From URL
DotLottiePlayerUIView(url: URL(string: "https://...")!, config: config)

// From animation data (JSON)
DotLottiePlayerUIView(animationData: jsonString, config: config)

// From dotlottie data
DotLottiePlayerUIView(dotLottieData: data, config: config)

// With existing animation
DotLottiePlayerUIView(dotLottieAnimation: animation, config: config)
```

### DotLottiePlayerView (SwiftUI)

```swift
// With existing animation
DotLottiePlayerView(animation: dotLottieAnimation)

// Async loading
DotLottiePlayerView {
    try await loadAnimation()
}

// Async with placeholder
DotLottiePlayerView {
    try await loadAnimation()
} placeholder: {
    ProgressView()
}
```

## Key Differences

| Feature | Original API | DotLottiePlayerUIView | DotLottiePlayerView |
|---------|-------------|---------------------|---------------------------|
| Platform | SwiftUI/UIKit | UIKit | SwiftUI |
| API Style | Direct calls | UIView properties | SwiftUI modifiers |
| Similar To | - | LottieAnimationView | LottieView |
| Auto Layout | Manual | UIKit constraints | SwiftUI layout |
| State Management | Observable | Properties | State bindings |

## Running the Examples

1. Open `DotLottieIosTestApp.xcodeproj`
2. Build and run the app
3. Navigate through the different examples from the main menu
4. Each example demonstrates different features and use cases

## Migration Guide

### From Original API to DotLottiePlayerUIView

```swift
// Before (Original)
let animation = DotLottieAnimation(fileName: "animation", config: config)
let view = DotLottieAnimationView(dotLottieViewModel: animation)
animation.play()

// After (New)
let playerView = DotLottiePlayerUIView(name: "animation", config: config)
playerView.play()
```

### From Original API to DotLottiePlayerView

```swift
// Before (Original)
let animation = DotLottieAnimation(fileName: "animation", config: config)
animation.view()

// After (New)
DotLottiePlayerView(animation: animation)
    .looping()
```

## Additional Resources

- [DotLottie iOS Documentation](https://github.com/LottieFiles/dotlottie-ios)
- [Lottie iOS Documentation](https://github.com/airbnb/lottie-ios)

