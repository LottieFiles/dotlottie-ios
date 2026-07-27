<p align="center">
  <img
    src="https://lottie.host/0c16cf7c-dd59-4926-9fd2-77e767b5bb13/Rxmlzk25G1.svg"
    alt="dotLottie iOS"
    width="550"
  />
</p>

<h1 align="center">dotLottie iOS</h1>

> [!TIP]
> Looking for animations to use with this player? Browse **[100,000+ free Lottie animations](https://lottiefiles.com/free-animations?utm_source=npm&utm_medium=readme)** and grab any of them as `.lottie` or `.json`, or create your own with [Lottie Creator](https://lottiefiles.com/lottie-creator?utm_source=npm&utm_medium=readme).

## Supported Devices

- Currently this package supports a mimimum iOS version of 13.0+ for iPhone and iPad.
- macOS is supported for versions 11.0+.
- watchOS is supported for v7.0+.
- tvOS is supported for v7.0+.
- visionOS is supported for v1.0+.

## Usage

> Full documentation available [on the developer portal](https://docs.lottiefiles.com/en/runtimes/distributions/ios).

1. Install the dependancy

Via the Swift Package Manager

To install via Swift Package Manager, in the package finder in Xcode, search for LottieFiles/dotlottie-ios or use the full Github path: https://github.com/LottieFiles/dotlottie-ios

2. Import DotLottie

```swift
import DotLottie
```

3. How to use

The ```DotLottieAnimation``` class will store the playback settings of your animation. It will also allow you to control playback via the play / pause functions.

3a. SwiftUI

Set up DotLottieAnimation inside a View. Optionally pass playback settings.

#### Load from an animation (.lottie / .json) from the main asset bundle.

```swift
struct AnimationView: View {
    var body: some View {
        DotLottieAnimation(fileName: "cool_animation", config: AnimationConfig(autoplay: true, loop: true)).view()
    }
}
```

#### Load an animation (.lottie / .json) from the web.

```swift
struct AnimationView: View {
    var body: some View {
        DotLottieAnimation(
            webURL: "https://lottie.host/link.lottie"
        ).view()
    }
}
```

#### Load directly from a String (.json).

```swift
struct AnimationView: View {
    var body: some View {
        DotLottieAnimation(
            animationData: "{"v":"4.8.0","meta":{"g":"LottieFiles AE..."
        ).view()
    }
}
```

3b. UIKit - Storyboard

Coming soon!

3c. UIKit - Programmatic approach

```swift
class AnimationViewController: UIViewController {
    var simpleVM = DotLottieAnimation(webURL: "https://lottie.host/link.lottie", config: AnimationConfig(autoplay: true, loop: false))
    
    override func viewWillAppear(_ animated: Bool) {
        let dotLottieView = simpleVM.view()
        view.addSubview(dotLottieView)
    }
}
```

## Alternative API: DotLottiePlayerUIView and DotLottiePlayerView

As an alternative to the `DotLottieAnimation` API, you can use `DotLottiePlayerUIView` (UIKit/AppKit) and `DotLottiePlayerView` (SwiftUI). These provide a familiar API similar to `LottieAnimationView` and `LottieView` from lottie-ios, making it easier for developers familiar with those libraries.

### UIKit/AppKit - DotLottiePlayerUIView

`DotLottiePlayerUIView` is a platform view (UIView on iOS, NSView on macOS) that provides a `LottieAnimationView`-like API for dotlottie animations.

#### Loading animations

```swift
// From bundle
let playerView = DotLottiePlayerUIView(
    name: "cool_animation",
    bundle: .main,
    config: AnimationConfig(autoplay: true, loop: true)
) { view, error in
    if let error = error {
        print("Error loading: \(error)")
    } else {
        print("Animation loaded!")
    }
}

// From URL
let playerView = DotLottiePlayerUIView(
    url: URL(string: "https://lottie.host/link.lottie")!,
    config: AnimationConfig()
)

// With existing DotLottieAnimation
let animation = DotLottieAnimation(fileName: "cool_animation", config: config)
let playerView = DotLottiePlayerUIView(dotLottieAnimation: animation, config: config)
```

#### Controlling playback

```swift
// Configure properties
playerView.loopMode = .loop
playerView.animationSpeed = 2.0

// Control playback
playerView.play()
playerView.pause()
playerView.stop()

// Access animation info
let progress = playerView.currentProgress
let frame = playerView.currentFrame
let totalFrames = playerView.totalFrames
```

### SwiftUI - DotLottiePlayerView

`DotLottiePlayerView` is a SwiftUI view that provides a `LottieView`-like API with modifier chains.

#### Basic usage

```swift
struct AnimationView: View {
    let animation = DotLottieAnimation(
        fileName: "cool_animation",
        config: AnimationConfig()
    )
    
    var body: some View {
        DotLottiePlayerView(animation: animation)
            .looping()
            .animationSpeed(2.0)
            .frame(height: 200)
    }
}
```

#### Async loading with placeholder

```swift
DotLottiePlayerView {
    // Load animation asynchronously
    let (data, _) = try await URLSession.shared.data(from: url)
    return DotLottieAnimation(dotLottieData: data, config: config)
} placeholder: {
    ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

#### Available modifiers

```swift
DotLottiePlayerView(animation: animation)
    .looping()                    // Loop the animation
    .playing()                    // Play once
    .paused()                     // Pause at current frame
    .playbackMode(.playing)       // Set playback mode
    .loopMode(.loop)              // Set loop mode
    .animationSpeed(2.0)          // Set playback speed
    .currentProgress(0.5)         // Set progress (0.0-1.0)
    .currentFrame(100)            // Set specific frame
    .mode(.bounce)                // Set playback mode
    .useFrameInterpolation(true)  // Enable frame interpolation
    .segments((0, 60))            // Play specific segment
    .configuration(config)        // Set animation configuration
    .animationDidLoad { animation in
        // Called when animation loads
    }
```

### When to use which API?

- **Use `DotLottieAnimation` + `DotLottieView`**: When you prefer the original API or need direct access to the animation model and player state.

- **Use `DotLottiePlayerUIView` / `DotLottiePlayerView`**: When you're familiar with lottie-ios APIs or want a more view-centric approach with properties and modifiers similar to `LottieAnimationView` and `LottieView`.

Both APIs are fully featured and support all dotlottie capabilities including state machines, interactivity, and theming.

## WebGPU renderer (experimental)

In addition to the default software renderer, dotLottie iOS ships a GPU-accelerated renderer backed by WebGPU (Metal). Pixels are written directly to a `CAMetalLayer` — the CPU pixel buffer and `CGImage` conversion used by the software path are bypassed entirely. This can be a significant win for large or heavy animations.

### SwiftUI - DotLottieWebGPUPlayerView

```swift
struct AnimationView: View {
    var body: some View {
        DotLottieWebGPUPlayerView(
            fileName: "cool_animation",
            config: Config(autoplay: true, loopAnimation: true)
        )
        .frame(height: 300)
    }
}
```

### UIKit/AppKit - DotLottieWebGPUView

```swift
let view = DotLottieWebGPUView(config: Config(autoplay: true, loopAnimation: true))
view.loadAnimation(fileName: "cool_animation")

// Playback
view.play()
view.pause()
view.stop()
```

### State machines

Name a state machine in the config and it is loaded and started automatically once the animation has finished loading. Taps and drags on the view are forwarded to the running state machine, so interactive animations work out of the box.

```swift
DotLottieWebGPUPlayerView(
    fileName: "cool_animation",
    config: Config(stateMachineId: "StateMachine1")
)
```

For runtime control, grab a reference to the underlying view via the `onViewCreated` callback (dispatched asynchronously, so it is safe to assign to `@State`). The underlying player is exposed via `view.player` for the full API (state-machine inputs, events, etc.):

```swift
struct AnimationView: View {
    @State private var gpuView: DotLottieWebGPUView?

    var body: some View {
        DotLottieWebGPUPlayerView(
            fileName: "cool_animation",
            config: Config(stateMachineId: "StateMachine1")
        ) { view in
            gpuView = view
        }
        .frame(height: 300)

        Button("Fire event") {
            gpuView?.player.stateMachineFireEvent(event: "toggle")
        }
    }
}
```

### Limitations

- **Platform support:** iOS (excluding Mac Catalyst) and macOS only. On all other platforms (Mac Catalyst, tvOS, watchOS, visionOS) use the software-rendering views above.
- **No background color customisation yet:** the WebGPU surface is rendered opaque, so transparent backgrounds and `Config.backgroundColor` are not currently honoured by this renderer. Use the software renderer if you need a transparent or custom background.

## API

### Properties

`DotLottieAnimation` instances expose the following properties:

| Property          | Type    | Description                                                                                                           |
| ----------------- | ------- | --------------------------------------------------------------------------------------------------------------------- |
| `currentFrame()`    | Float  | Represents the animation's currently displayed frame number.                                                          |
| `duration()`        | Float  | Specifies the animation's total playback time in milliseconds.                                                        |
| `totalFrames()`     | Float  | Denotes the total count of individual frames within the animation.                                                    |
| `loop()`            | Bool | Indicates if the animation is set to play in a continuous loop.                                                       |
| `speed()`           | Float  | Represents the playback speed factor; e.g., 2 would mean double speed.                                                |
| `loopCount()`       | Int  | Tracks how many times the animation has completed its loop.                                                           |
| `mode()`            | Mode  | Reflects the current playback mode.                                                                                   |
| `isPaused()`        | Bool | Reflects whether the animation is paused or not.                                                                      |
| `isStopped()`       | Bool | Reflects whether the animation is stopped or not.                                                                     |
| `isPlaying()`       | Bool | Reflects whether the animation is playing or not.                                                                     |
| `manifest()`       | Manifst | Returns the .lottie's manifest file.                                                                     |
| `segments()`        | (Float, Float)  | Reflects the frames range of the animations. where segments\[0] is the start frame and segments\[1] is the end frame. |
| `backgroundColor()` | CIImage  | Gets the background color of the canvas.                                                                              |
| `autoplay()`        | Bool | Indicates if the animation is set to auto play.                                                                       |
| `useFrameInterpolation()`        | Bool | Determines if the animation should update on subframes. If set to false, the original AE frame rate will be maintained. If set to true, it will refresh with intermediate values. The default setting is true.                          |

### Methods

`DotLottieAnimation` instances expose the following methods that can be used to control the animation:

| Event       | Description                                                             | 
| ----------- | ----------------------------------------------------------------------- | 
| `play()` | Begins playback from the current animation position. |
| `play(fromFrame: Float)` | Begins playback from a specific animation frame. |
| `play(fromProgress: Float)` | Begins playback from a specific animation progress (0...1). |
| `pause()` | Pauses the animation without resetting its position. |
| `stop()` | Halts playback and returns the animation to its initial frame. |
| `setSpeed(speed: Int)` | Sets the playback speed with the given multiplier. |
| `setLoop(loop: Bool)` | Configures whether the animation should loop continuously. |
| `setFrame(frame: Float)` | Directly navigates the animation to a specified frame. |
| `setProgress(progress: Float)` | Directly navigates the animation to a specified progress (0...1). |
| `loadAnimationById(_ animationId: String)` | Loads the animation by id. Animation id's are visible inside the manifest, recoverable via the manifest() method. |
| `setMode(mode: Mode)` | Sets the animation play mode. |
| `setSegments(segments: (Float, Float))` | Sets the start and end frame of the animation. |
| `setBackgroundColor(color: CIImage)` | Sets the background color of the animation. |
| `setFrameInterpolation(_ useFrameInterpolation: Bool)` | Uses frame interpolation or not. |
| `resize(width: Int, height: Int)` | Manually resizes the animation. |
| `setTheme(_ themeId: String)` | Loads a theme. Only available with .lottie files. |
| `setThemeData(_ themeData: String)` | Loads the passed theming data. |
| `resetTheme()` | Removes the currently loaded theme. Only available with .lottie files. |

### Event callbacks

The `DotLottieAnimation` instance emits the following events that can be listened to via a class implementing the `Observer` protocol:

```swift
class YourDotLottieObserver: Observer {
    func onComplete() {
    }
    
    func onFrame(frameNo: Float) {
    }
    
    func onLoad() {
    }
    
    func onLoadError() {
    }
    
    func onLoop(loopCount: UInt32) {
    }
    
    func onPause() {
    }
    
    func onPlay() {
    }
    
    func onRender(frameNo: Float) {
    }
    
    func onStop() {
    }
}

// In your view code

var animation = DotLottieAnimation(...)
var animationView = DotLottieView(dotLottie: animation)
var myObserver = YourDotLottieObserver()

animationView.subscribe(observer: myObserver)

```


| Event       | Description                                                             | 
| ----------- | ----------------------------------------------------------------------- | 
| `onComplete`  | Emitted when the animation completes.                                   |
| `onFrame(frameNo: Float)`     | Emitted when the animation reaches a new frame.         |
| `onLoad`      | Emitted when the animation is loaded.                                   |
| `onLoadError` | Emitted when the animation failed to load.                         |
| `onLoop(loopCount: UIint32)`      | Emitted when the animation completes a loop.        |
| `onPause`     | Emitted when the animation is paused.                                   |
| `onPlay`      | Emitted when the animation starts playing.                              |
| `onRender(frameNo: Float)`     | Emitted when the frame is rendered.                    |
| `onStop`      | Emitted when the animation is stopped.                                  |
