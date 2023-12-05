# @lottiefiles/dotLottie-ios

### iOS player for .lottie and .json files.

<p align="center">
  <img src="https://user-images.githubusercontent.com/23125742/201124166-c2a0bc2a-018b-463b-b291-944fb767b5c2.png" />
</p>

> 🚧 **Beta Alert:** We're still refining! The APIs in this package may undergo changes.

## ⚠️ Currently supported platforms ⚠️

- iPhone, iPhone Simulator (x86), MacOS (x86, ARM)


Note: This is due to the compilation of Thorvg. We're working on supporting more platforms!

## Usage

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

```swift
struct AnimationView: View {
    var body: some View {
        DotLottieAnimation(fileName: "cool_animation", autoplay: true, loop: true).view()
    }
}
```


In the above example, you reference the name of a .lottie asset bundled inside your application, but you can also load in a .lottie file hosted on a web URL:

```swift
struct AnimationView: View {
    var body: some View {
        DotLottieAnimation(
            webURL: "https://lottie.host/link.lottie"
        ).view()
    }
}
```

3b. UIKit - Storyboard

Coming soon!

3c. UIKit - Programmatic approach

```swift
class AnimationViewController: UIViewController {
    var simpleVM = DotLottieAnimation(webURL: "https://lottie.host/link.lottie", autoplay: true, loop: false)
    
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
| `currentFrame()`    | Float32  | Represents the animation's currently displayed frame number.                                                          |
| `duration()`        | Float32  | Specifies the animation's total playback time in milliseconds.                                                        |
| `totalFrames()`     | Float32  | Denotes the total count of individual frames within the animation.                                                    |
| `loop()`            | Bool | Indicates if the animation is set to play in a continuous loop.                                                       |
| `speed()`           | Float32  | Represents the playback speed factor; e.g., 2 would mean double speed.                                                |
| `loopCount()`       | Float32  | Tracks how many times the animation has completed its loop.                                                           |
| `direction()`       | Int  | Reflects the current playback direction; e.g., 1 would mean forward, -1 would mean reverse.                           |
| `mode()`            | Mode  | Reflects the current playback mode.                                                                                   |
| `isPaused()`        | Bool | Reflects whether the animation is paused or not.                                                                      |
| `isStopped()`       | Bool | Reflects whether the animation is stopped or not.                                                                     |
| `isPlaying()`       | Bool | Reflects whether the animation is playing or not.                                                                     |
| `segments()`        | (Float32, Float32)  | Reflects the frames range of the animations. where segments\[0] is the start frame and segments\[1] is the end frame. |
| `backgroundColor()` | UIColor / NSColor  | Gets the background color of the canvas.                                                                              |
| `autoplay()`        | Bool | Indicates if the animation is set to auto play.                                                                       |
| `isFrozen()`        | Bool | Reflects whether the animation loop is stopped or not.                                                                |

### Methods

`DotLottieAnimation` instances expose the following methods that can be used to control the animation:

| Event       | Description                                                             | 
| ----------- | ----------------------------------------------------------------------- | 
| `play()` | Begins playback from the current animation position. |
| `pause()` | Pauses the animation without resetting its position. |
| `stop()` | Halts playback and returns the animation to its initial frame. |
| `setSpeed(speed: Int)` | Sets the playback speed with the given multiplier. |
| `setLoop(loop: Bool)` | Configures whether the animation should loop continuously. |
| `setFrame(frame: Float32)` | Directly navigates the animation to a specified frame. |
| `load(config: Config)` | Loads a new configuration or a new animation. |
| `setMode(mode: Mode)` | Sets the animation play mode. |
| `setSegments(segments: (Float32, Float32))` | Sets the start and end frame of the animation. |
| `freeze()` | Freezes the animation by stopping the animation loop. |
| `unFreeze()` | Unfreezes the animation by resuming the animation loop. |
| `setBackgroundColor(color: UIColor / NSColor)` | Sets the background color of the animation. |

### Event callbacks

The `DotLottieAnimation` instance emits the following events that can be listened to via the `on` method:

| Event       | Description                                                             | 
| ----------- | ----------------------------------------------------------------------- | 
| `load`      | Emitted when the animation is loaded.                                   |
| `loadError` | Emitted when there's an error loading the animation.                    |
| `play`      | Emitted when the animation starts playing.                              |
| `pause`     | Emitted when the animation is paused.                                   |
| `stop`      | Emitted when the animation is stopped.                                  |
| `loop`      | Emitted when the animation completes a loop.                            |
| `complete`  | Emitted when the animation completes.                                   |
| `frame`     | Emitted when the animation reaches a new frame.                         |
| `freeze`    | Emitted when the animation is freezed and the animation loop stops.     |
| `unfreeze`  | Emitted when the animation is unfreezed and the animation loop resumes. |

## Development

### How to build thorvg.xcframework

(Only for maintainers of the repository)

- Pull the Thorvg submodule:

```bash
git submodule update --init --recursive
```

- Go in to the Thorvg folder:

```bash
cd Sources/Thorvg/
```

- Run the ```build_thorvg.sh``` script:

```bash
sh build_thorvg.sh -h
```

- How to cross compile for your architecture:

For example if you're on a x86 based CPU:

```bash
sh build_thorvg.sh iphone_sim_x86_64 macos_x86_64 
```

For example if you're on a ARM basd CPU:

```bash
sh build_thorvg.sh iphone_sim_aarch macos_aarch 
```

Build for real iPhone device:

```bash
sh build_thorvg.sh iphone_aarch
```
