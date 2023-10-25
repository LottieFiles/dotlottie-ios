# DotLottie

### iOS player for .lottie and .json files.

The rendering backend used is "Thorvg".

## ⚠️ Currently supported platforms ⚠️

- iPhone

Please make sure that your build target in XCode is set to iPhone.

Note: This is due to the compilation of Thorvg currenly only building for x86_64


## How to build the Thorvg.xcframework.zip

- Enter the (Thorvg repo)[https://github.com/thorvg/thorvg]
- Include this swift wrapper code at the root of the project:

```Swift
//
//  DrawLottie.swift
//  DotLottieIos
//
//  Created by Sam on 17/10/2023.
//

import Foundation
import CoreGraphics

class ThorvgWrapper {
//    var buffer: [UInt32] = [] // This is where you'll store the pixel data buffer.
    var animation: OpaquePointer;
    var canvas: OpaquePointer;
    var current_frame: UnsafeMutablePointer<UInt32> = UnsafeMutablePointer<UInt32>.allocate(capacity: 1);
    var total_frames: UnsafeMutablePointer<UInt32> = UnsafeMutablePointer<UInt32>.allocate(capacity: 1);
    var WIDTH: UInt32 = 0;
    var HEIGHT: UInt32 = 0;
    
    init() {
        print("INITING ENGINE!");
        
        tvg_engine_init(TVG_ENGINE_SW, 0);
        
        self.animation = tvg_animation_new();
        self.canvas = tvg_swcanvas_create();
//        self.buffer =  Array(repeating: 0, count: WIDTH * HEIGHT)
        self.total_frames.pointee = 0;
        self.current_frame.pointee = 0;
    }
    
    func load_animation(buffer: UnsafeMutablePointer<UInt32>, animation_data: String, width: UInt32, height: UInt32) {
        self.WIDTH = width;
        self.HEIGHT = height;
        
        tvg_swcanvas_set_target(self.canvas, buffer, width, width, height, TVG_COLORSPACE_ARGB8888);
        
        let frame_image = tvg_animation_get_picture(self.animation);
        
        var load_result: Tvg_Result = TVG_RESULT_UNKNOWN;
        
       if let c_string = animation_data.cString(using: .utf8) {
            let unsafePointer = UnsafePointer<CChar>(c_string)
            
            load_result = tvg_picture_load_data(frame_image, unsafePointer, numericCast(strlen(animation_data)), "lottie", false);
        }
            // cStringPointer is an UnsafePointer<CChar>
            // You can work with cStringPointer within this closure
            
            // For example, you can pass it to a C function that expects an UnsafePointer<CChar>
            // SomeCFunction(
                
        if (load_result != TVG_RESULT_SUCCESS ) {
            tvg_animation_del(self.animation)
        } else {
            print("Animation has loaded!");
            
            tvg_paint_scale(frame_image, 1.0);
            
            tvg_animation_get_total_frame(self.animation, self.total_frames);
            
            tvg_animation_set_frame(animation, 0);
            tvg_canvas_push(self.canvas, frame_image);
            tvg_canvas_draw(self.canvas);
            tvg_canvas_sync(self.canvas);
            
            print("Total frames:  \(total_frames.pointee)");
        }
    }
    
    func tick() {
        tvg_animation_get_frame(animation, current_frame);

        // todo add direction -1
        if current_frame.pointee >= total_frames.pointee - 1 {
            current_frame.pointee = 0;
        } else {
            current_frame.pointee += 1;
        }
        
        print("Current frame \(current_frame.pointee)")
        
        tvg_animation_set_frame(animation, current_frame.pointee);

        tvg_canvas_update_paint(canvas, tvg_animation_get_picture(animation));

        //Draw the canvas
        tvg_canvas_draw(canvas);
        tvg_canvas_sync(canvas);
    }
    
    func render() -> CGImage? {
        let bitsPerComponent = 8
        let bytesPerRow = 4 * WIDTH
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt32](repeating: 0, count: Int(WIDTH * HEIGHT))
        
        if let context = CGContext(data: &pixelData, width: Int(WIDTH), height: Int(HEIGHT), bitsPerComponent: bitsPerComponent, bytesPerRow: Int(bytesPerRow), space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                if let newImage = context.makeImage() {
//                    print("Returning new image!");
//                    print(newImage)
                    
                    return newImage
                }
            }
        return nil
    }
}
```

- Run this bash script: 

```bash
#!/bin/bash
# meson setup --backend=ninja build -Dlog=true -Dloaders="all" -Ddefault_library=static -Dstatic=true -Dsavers="all" -Dbindings="capi" --cross-file ./cross/ios_x86_64.txt
meson setup --backend=ninja build -Dlog=true -Dloaders="all" -Dsavers="all" -Dbindings="capi" --cross-file ./cross/ios_x86_64.txt
# meson setup --backend=ninja build -Dlog=true -Dloaders="all" -Dsavers="all" -Dbindings="capi" --cross-file ./cross/ios_aarch64.txt

ninja -C build install

# Set up initial configurations and paths
PLISTBUDDY_EXEC="/usr/libexec/PlistBuddy"
BINDINGS=./src/bindings/capi/thorvg_capi.h

# Create the include directory and set up module map
mkdir -p ./artifacts/include/

cp $BINDINGS ./artifacts/include/thorvg_capi.h

cat << EOF > "./artifacts/include/module.modulemap"
framework module Thorvg {
  umbrella header "thorvg_capi.h"
  export *
  module * { export * }
}
EOF

# Combine libraries using lipo
mkdir -p ./artifacts/ios-simulator-arm64_x86_64
# mkdir -p ./artifacts/aarch64-apple-ios

# old
# lipo -create \
#     "./target/aarch64-apple-ios-sim/release/libthorvg.dylib" \
#     "./target/x86_64-apple-ios/release/libthorvg.dylib" \
#     -o "./artifacts/ios-simulator-arm64_x86_64/libthorvg.dylib"

#prod
lipo -create \
    "./build/src/libthorvg.dylib" \
    -o "./artifacts/ios-simulator-arm64_x86_64/libthorvg.dylib"


# lipo -create \
    # "./target/aarch64-apple-ios/release/libdlutils.dylib" \
    # -o "./artifacts/aarch64-apple-ios/libdlutils.dylib"

# Prepare the framework for each target
# for TARGET_TRIPLE in "aarch64-apple-ios"  "ios-simulator-arm64_x86_64"; do
for TARGET_TRIPLE in "ios-simulator-arm64_x86_64" ; do
    FRAMEWORK_PATH="./artifacts/$TARGET_TRIPLE/Thorvg.framework"
    
    mkdir -p $FRAMEWORK_PATH/Headers
    mkdir -p $FRAMEWORK_PATH/Modules
    
    mv ./artifacts/$TARGET_TRIPLE/libthorvg.dylib $FRAMEWORK_PATH/Thorvg
    cp $BINDINGS $FRAMEWORK_PATH/Headers/
    cp ./artifacts/include/module.modulemap $FRAMEWORK_PATH/Modules/

    # Set up the plist for the framework
    $PLISTBUDDY_EXEC -c "Add :CFBundleIdentifier string com.thorvg.Thorvg" \
                    -c "Add :CFBundleName string Thorvg" \
                    -c "Add :CFBundleDisplayName string Thorvg" \
                    -c "Add :CFBundleVersion string 1.0.0" \
                    -c "Add :CFBundleShortVersionString string 1.0.0" \
                    -c "Add :CFBundlePackageType string FMWK" \
                    -c "Add :CFBundleExecutable string Thorvg" \
                    -c "Add :MinimumOSVersion string 16.4" \
                    -c "Add :CFBundleSupportedPlatforms array" \
                    $FRAMEWORK_PATH/Info.plist

    case $TARGET_TRIPLE in
        aarch64-apple-ios)
            $PLISTBUDDY_EXEC -c "Add :CFBundleSupportedPlatforms:0 string iPhoneOS" $FRAMEWORK_PATH/Info.plist
            ;;
        ios-simulator-arm64_x86_64)
            $PLISTBUDDY_EXEC -c "Add :CFBundleSupportedPlatforms:0 string iPhoneOS" \
                             -c "Add :CFBundleSupportedPlatforms:1 string iPhoneSimulator" \
                             $FRAMEWORK_PATH/Info.plist
            ;;
        *)
            ;;
    esac

    install_name_tool -id @rpath/Thorvg.framework/Thorvg $FRAMEWORK_PATH/Thorvg
done

# Create the XCFramework
xcodebuild -create-xcframework \
    -framework "./artifacts/ios-simulator-arm64_x86_64/Thorvg.framework" \
    -output "./artifacts/Thorvg.xcframework"

    # -framework "./artifacts/aarch64-apple-ios/Thorvg.framework" \
echo "Done creating Thorvg.xcframework!"

BASE_DIR=./ios
rm -rf $BASE_DIR;

# Creating Framework folder
mkdir -p $BASE_DIR/Framework
mkdir -p $BASE_DIR/Bindings

cp -R ./artifacts/Thorvg.xcframework $BASE_DIR/Framework

# todo ask afsal
# cp $BINDINGS/thorvg.swift $BASE_DIR/Bindings
cp ./thorvg.swift $BASE_DIR/Bindings
sed -i "" -E 's/[[:<:]]thorvgFFI[[:>:]]/Thorvg/g' $BASE_DIR/Bindings/thorvg.swift

#clean up
rm -rf ./artifacts

echo "Done generating ios Framework"

```
