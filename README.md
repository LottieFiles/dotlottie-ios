# dotLottie

### iOS player for .lottie and .json files.

The rendering backend used is "Thorvg".

## ⚠️ Currently supported platforms ⚠️

- iPhone

Please make sure that your build target in XCode is set to iPhone.

Note: This is due to the compilation of Thorvg currenly only building for x86_64


## How to build thorvg.xcframework

If you want to change / add targets, modify the ```build_ios.sh``` script.
It currently is targeting ```ios_x86_64```.

- Pull the Thorvg submodule:

```bash
git submodule update --init --recursive
```

- Go in to the Thorvg folder:

```bash
cd Sources/Thorvg/
```

- Run the ```build_ios.sh``` script:

```bash
sh build_ios.sh
```
