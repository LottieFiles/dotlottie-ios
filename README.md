# dotLottie

### iOS player for .lottie and .json files.

The rendering backend used is "Thorvg".

## ⚠️ Currently supported platforms ⚠️

- iPhone

Please make sure that your build target in XCode is set to iPhone.

Note: This is due to the compilation of Thorvg currenly only building for x86_64

## Usage

1. Install the dependancy

Via the Swift Package Manager

To install via Swift Package Manager, in the package finder in Xcode, search for LottieFiles/dotlottie-ios or use the full Github path: https://github.com/LottieFiles/dotlottie-ios

2. Import DotLottie

```swift
import DotLottie
```

3. How to use

The ```DotLottieViewModel``` class will store the playback settings of your animation. It will also allow you to control playback via the play / pause functions.

3a. SwiftUI

Set up DotLottieViewModel inside a View. Optionally pass playback settings.

```swift
struct AnimationView: View {
    var body: some View {
        DotLottieViewModel(fileName: "cool_animation", autoplay: true, loop: true).view()
    }
}
```


In the above example, you reference the name of a .lottie asset bundled inside your application, but you can also load in a .lottie file hosted on a web URL:

```swift
struct AnimationView: View {
    var body: some View {
        DotLottieViewModel(
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
    var simpleVM = DotLottieViewModel(webURL: "https://lottie.host/link.lottie", autoplay: true, loop: false)
    
    override func viewWillAppear(_ animated: Bool) {
        let dotLottieView = simpleVM.createDotLottieView()
        view.addSubview(dotLottieView)
    }
}
```

## How to build thorvg.xcframework

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
