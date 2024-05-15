# @lottiefiles/dotLottie-ios

### iOS player for .lottie and .json files.

<p align="center">
  <img src="https://user-images.githubusercontent.com/23125742/201124166-c2a0bc2a-018b-463b-b291-944fb767b5c2.png" />
</p>

## Supported Devices

Currently this package supports a mimimum iOS version of 15.4+ for iPhone and iPad.
MacOS is supported for versions 12.0 and upwards.

## Usage

> Full documentation available [on the developer portal](https://developers.lottiefiles.com/docs/dotlottie-ios/).

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
        let dotLottieView = simpleVM.createDotLottieView()
        view.addSubview(dotLottieView)
    }
}
```

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
| `pause()` | Pauses the animation without resetting its position. |
| `stop()` | Halts playback and returns the animation to its initial frame. |
| `setSpeed(speed: Int)` | Sets the playback speed with the given multiplier. |
| `setLoop(loop: Bool)` | Configures whether the animation should loop continuously. |
| `setFrame(frame: Float)` | Directly navigates the animation to a specified frame. |
| `load(config: Config)` | Loads a new configuration or a new animation. |
| `loadAnimation(animationId: String)` | Loads the animation by id. Animation id's are visible inside the manifest, recoverable via the manifest() method. |
| `setMode(mode: Mode)` | Sets the animation play mode. |
| `setSegments(segments: (Float, Float))` | Sets the start and end frame of the animation. |
| `setBackgroundColor(color: CIImage)` | Sets the background color of the animation. |
| `setFrameInterpolation(useFrameInterpolation: Bool)` | Use frame interpolation or not. |
| `resize(width: Int, height: Int)` | Manually resize the animation. |

### Event callbacks

The `DotLottieAnimation` instance emits the following events that can be listened to via a class implementing the `Observer` protocol:

```
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
