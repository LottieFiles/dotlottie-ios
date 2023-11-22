# dotLottie

### iOS player for .lottie and .json files.

The rendering backend used is "Thorvg".

## ⚠️ Currently supported platforms ⚠️

- iPhone

Please make sure that your build target in XCode is set to iPhone.

Note: This is due to the compilation of Thorvg currenly only building for x86_64


## How to build thorvg.xcframework

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
