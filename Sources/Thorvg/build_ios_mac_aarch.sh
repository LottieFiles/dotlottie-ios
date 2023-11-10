#!/bin/bash

rm -rf ./ios/

cd ./Thorvg/

meson setup --backend=ninja ios-build -Dloaders="all" -Dsavers="all" -Dbindings="capi" --cross-file ./cross/ios_aarch64.txt
ninja -C ios-build install

meson setup --backend=ninja macos-build -Dloaders="all" -Dsavers="all" -Dbindings="capi" --cross-file ../macos_aarch.txt
ninja -C macos-build install


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
mkdir -p ./artifacts/ios-simulator-aarch64
mkdir -p ./artifacts/macosx_aarch
# mkdir -p ./artifacts/aarch64-apple-ios

# old
# lipo -create \
#     "./target/aarch64-apple-ios-sim/release/libthorvg.dylib" \
#     "./target/x86_64-apple-ios/release/libthorvg.dylib" \
#     -o "./artifacts/ios-simulator-aarch64/libthorvg.dylib"

#prod
lipo -create \
    "./ios-build/src/libthorvg.dylib" \
    -o "./artifacts/ios-simulator-aarch64/libthorvg.dylib"
lipo -create \
    "./macos-build/src/libthorvg.dylib" \
    -o "./artifacts/macosx_aarch/libthorvg.dylib"


# lipo -create \
    # "./target/aarch64-apple-ios/release/libdlutils.dylib" \
    # -o "./artifacts/aarch64-apple-ios/libdlutils.dylib"

# Prepare the framework for each target
# for TARGET_TRIPLE in "aarch64-apple-ios"  "ios-simulator-aarch64"; do
for TARGET_TRIPLE in "ios-simulator-aarch64" "macosx_aarch" ; do
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
        macosx_aarch)
            $PLISTBUDDY_EXEC -c "Add :CFBundleSupportedPlatforms:1 string MacOSX" $FRAMEWORK_PATH/Info.plist
            ;;
        ios-simulator-aarch64)
            $PLISTBUDDY_EXEC -c "Add :CFBundleSupportedPlatforms:0 string iPhoneOS" \
                             -c "Add :CFBundleSupportedPlatforms:1 string iPhoneSimulator" \
                             $FRAMEWORK_PATH/Info.plist
            ;;
        *)
            ;;
    esac

    install_name_tool -id @rpath/Thorvg.framework/Thorvg $FRAMEWORK_PATH/Thorvg
done

echo "A"

# Create the XCFramework
xcodebuild -create-xcframework \
    -framework "./artifacts/macosx_aarch/Thorvg.framework" \
    -framework "./artifacts/ios-simulator-aarch64/Thorvg.framework" \
    -output "./artifacts/Thorvg.xcframework"

    # -framework "./artifacts/aarch64-apple-ios/Thorvg.framework" \
echo "Done creating Thorvg.xcframework!"

BASE_DIR=./ios
rm -rf $BASE_DIR;

# Creating Framework folder
mkdir -p $BASE_DIR/Framework
mkdir -p $BASE_DIR/Bindings

cp -R ./artifacts/Thorvg.xcframework $BASE_DIR/Framework

WRAPPER_FILE=../../DotLottie/Public/Thorvg.swift
WRAPPER_FILE_NAME=Thorvg.swift
cp $WRAPPER_FILE $BASE_DIR/Bindings
sed -i "" -E 's/[[:<:]]thorvgFFI[[:>:]]/Thorvg/g' $BASE_DIR/Bindings/$WRAPPER_FILE_NAME

#clean up
rm -rf ./artifacts

# move the generated folder up
mv ios ../

echo "Done generating ios Framework"

