#!/bin/bash
#
# Prepares DotLottiePlayer.xcframework for CocoaPods distribution: re-packaged
# from the SPM xcframework with the watchOS slices removed (CocoaPods
# integration doesn't need them).
#
# WgpuNative needs no preparation — it ships as a framework-based xcframework,
# which CocoaPods vendors directly from Sources/DotLottieCore/.
#
# Output lands in Sources/DotLottieCore/cocoapods/.

set -euo pipefail

ROOT="Sources/DotLottieCore"
COCOAPODS_DIR="$ROOT/cocoapods"

# ---------------------------------------------------------------------------
# DotLottiePlayer — drop the watchOS slices.
# ---------------------------------------------------------------------------
rm -rf "$COCOAPODS_DIR/DotLottiePlayer.xcframework"
xcodebuild -create-xcframework \
    -framework "$ROOT/DotLottiePlayer.xcframework/ios-arm64/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/ios-arm64_x86_64-simulator/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/ios-arm64_x86_64-maccatalyst/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/macos-arm64_x86_64/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/tvos-arm64/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/tvos-arm64-simulator/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/xros-arm64/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/xros-arm64-simulator/DotLottiePlayer.framework" \
    -output "$COCOAPODS_DIR/DotLottiePlayer.xcframework"

# ---------------------------------------------------------------------------
# Fix stale libwgpu_native references.
#
# Most DotLottiePlayer slices already link wgpu as
# "@rpath/WgpuNative.framework/WgpuNative", but the iOS arm64 *simulator* slice
# still points at the absolute CI build path it was linked against
# (.../deps/libwgpu_native.dylib), which resolves nowhere at runtime: the app
# crashes at launch with "Library not loaded: .../libwgpu_native.dylib".
# Rewrite any surviving libwgpu_native reference, across all arch slices, to the
# framework's install name.
# ---------------------------------------------------------------------------
WGPU_INSTALL_NAME="@rpath/WgpuNative.framework/WgpuNative"
while IFS= read -r dlp_bin; do
    refs=$(for arch in $(lipo -archs "$dlp_bin"); do
        otool -arch "$arch" -L "$dlp_bin"
    done | awk '/libwgpu_native\.dylib/ { print $1 }' | sort -u)
    for ref in $refs; do
        install_name_tool -change "$ref" "$WGPU_INSTALL_NAME" "$dlp_bin"
    done
done < <(find "$COCOAPODS_DIR/DotLottiePlayer.xcframework" \
    -type f -name DotLottiePlayer -path '*/DotLottiePlayer.framework/*')
