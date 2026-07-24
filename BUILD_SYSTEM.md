## Building the vendored XCFramework

This repo owns the Apple XCFramework build for `deps/dotlottie-rs` (a git submodule). `make apple` builds every supported platform slice — iOS, macOS, Mac Catalyst, tvOS, visionOS, and watchOS — and installs the result directly into source control:

```bash
git submodule update --init --recursive
make apple-setup   # one-time: Rust targets, nightly rust-src, pre-warm Cargo + wgpu-native caches (requires network)
make apple         # builds + installs into Sources/DotLottieCore/ and Sources/DotLottie/Public/
```

WebGPU (the `tvg-wg` Metal-backed renderer, macOS/iOS/Mac Catalyst only) ships by default alongside the software renderer, which also produces and installs `Sources/DotLottieCore/WgpuNative.xcframework` (the wgpu-native shared library `DotLottiePlayer` links against). Pass `WEBGPU=0` for a leaner, wgpu-free build:

```bash
make apple WEBGPU=0
```

Run `./cocoapods-release.sh` afterward to refresh the CocoaPods-facing copy in `Sources/DotLottieCore/cocoapods/`.

See `make help` for the full target list (per-platform builds, `apple-clean`, etc.).

## Custom Builds

By default, dotLottie-iOS uses a prebuilt XCFramework with all standard features enabled. This works great for most use cases and requires no additional setup.

If you need **smaller binary sizes** you can build a custom framework with only the features you need:

### Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/LottieFiles/dotlottie-ios.git
cd dotlottie-ios

# 2. Initialize submodules
git submodule update --init --recursive

# 3. Edit configuration
nano Configuration/BuildConfig.json

# 4. Build custom framework
swift package plugin --allow-writing-to-package-directory build-custom-framework

# 5. Update Package.swift to use custom build
# Change path to: "./Sources/DotLottieCore/Custom/DotLottiePlayer.xcframework"
```

Custom builds always include WebGPU — Xcode requires it — so `WgpuNative.xcframework` is also built and copied into `Sources/DotLottieCore/Custom/` alongside `DotLottiePlayer.xcframework`; both must ship together.

### Prerequisites

**Required:** Rust toolchain (rustup, cargo, nightly)

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install nightly toolchain
rustup toolchain install nightly

# Verify installation
./Scripts/validate-environment.sh
```

### Why Build Custom?

✅ **Reduce binary size by 30-60%** - Disable unused image formats and features
✅ **Optimize for your use case** - Enable only PNG if that's all you use

**Note:** Custom builds are for advanced users who need specific optimizations. The standard prebuilt framework works perfectly for most applications.

---
    