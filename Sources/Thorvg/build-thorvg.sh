#!/bin/bash

# ----------- VARIABLES -----------
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
THORVG_LOADERS="all"
PLISTBUDDY_EXEC="/usr/libexec/PlistBuddy"
BINDINGS=./src/bindings/capi/thorvg_capi.h
BASE_DIR="./exports"
IOS_BUILD_DIR="./Thorvg/ios-build"
MACOS_BUILD_DIR="./Thorvg/macos-build/"

# Cross files
IPHONE_X86_SIM_CROSS="../cross/iphone_sim_x86_64.txt"
IPHONE_AARCH_SIM_CROSS="../cross/iphone_sim_aarch.txt"
MACOS_X86_CROSS="../cross/macos_x86_64.txt"
MACOS_AARCH="../cross/macos_aarch.txt"
IPHONE_AARCH="../cross/iphone_aarch.txt"

WRAPPER_FILE=../../DotLottie/Public/Thorvg.swift
WRAPPER_FILE_NAME=Thorvg.swift

THORVG_FLAGS="-Ddefault_library=static -Dstatic=true -Dloaders=$THORVG_LOADERS -Dsavers=all  -Dbindings=capi"
# ----------- VARIABLES -----------

# ----------- FUNCTIONS -----------

display_help() {
    echo "
  ╔╦╗┬ ┬┌─┐┬─┐┬  ┬┌─┐  ┌─┐┬─┐┌─┐┌┬┐┌─┐┬ ┬┌─┐┬─┐┬┌─  ┌─┐┌─┐┌┐┌┌─┐┬─┐┌─┐┌┬┐┌─┐┬─┐
   ║ ├─┤│ │├┬┘└┐┌┘│ ┬  ├┤ ├┬┘├─┤│││├┤ ││││ │├┬┘├┴┐  │ ┬├┤ │││├┤ ├┬┘├─┤ │ │ │├┬┘
   ╩ ┴ ┴└─┘┴└─ └┘ └─┘  └  ┴└─┴ ┴┴ ┴└─┘└┴┘└─┘┴└─┴ ┴  └─┘└─┘┘└┘└─┘┴└─┴ ┴ ┴ └─┘┴└─             
    "
    echo "Usage: $(basename "$0") [options] arguments..."
    echo "Options:" 
    echo "  -h, --help     Display this help message"
    echo "  -c, --clean    Remove all files related to this CLI"
    echo "Arguments:"
    echo "  iphone_aarch: Build for iPhone arm64"
    echo "  all: Build all targets"
    echo "  iphone_sim_aarch: Build for iPhone simulator arm64"
    echo "  iphone_sim_x86_64: Build for iPhone simulator x86_64"
    echo "  macos_aarch: Build for macOS arm64"
    echo "  macos_x86_64: Build for macOS x86_64"
}

display_success() {
echo " __           _       _                               _      _           _                                   __       _ _       ";
echo "/ _\ ___ _ __(_)_ __ | |_    ___ ___  _ __ ___  _ __ | | ___| |_ ___  __| |  ___ _   _  ___ ___ ___ ___ ___ / _|_   _| | |_   _ ";
echo "\ \ / __| '__| | '_ \| __|  / __/ _ \| '_ \` _ \| '_ \| |/ _ | __/ _ \/ _\` | / __| | | |/ __/ __/ _ / __/ __| |_| | | | | | | | |";
echo "_\ | (__| |  | | |_) | |_  | (_| (_) | | | | | | |_) | |  __| ||  __| (_| | \__ | |_| | (_| (_|  __\__ \__ |  _| |_| | | | |_| |";
echo "\__/\___|_|  |_| .__/ \__|  \___\___/|_| |_| |_| .__/|_|\___|\__\___|\__,_| |___/\__,_|\___\___\___|___|___|_|  \__,_|_|_|\__, |";
echo "               |_|                             |_|                                                                        |___/ ";
}

cleanup() {
    echo "${GREEN} Commencing cleanup... ${NC}"
    rm -rf exports Thorvg/iphone_aarch Thorvg/iphone_sim_aarch Thorvg/iphone_sim_x86_64 Thorvg/macos_x86_64 Thorvg/macos_aarch
    echo "${GREEN} Finished cleanup! ${NC}"
}

# Function to execute a command and check its return value
execute_and_check() {
    "$@"  # Execute the command passed as arguments to the function

    # Check the return value using $?
    if [ $? -ne 0 ]; then
        echo "$RED Command failed: $* $NC"
        exit 1  # Exit the script if the command fails
    else
        echo "$GREEN Command was successful: $* $NC"
    fi
}

build_iOS_sim_x86() {
    execute_and_check meson . iphone_sim_x86_64 $THORVG_FLAGS --cross-file "$IPHONE_X86_SIM_CROSS"
    execute_and_check ninja -C iphone_sim_x86_64 install
}

build_iOS_sim_aarch() {
    execute_and_check meson . iphone_sim_aarch $THORVG_FLAGS --cross-file "$IPHONE_AARCH_SIM_CROSS"
    execute_and_check ninja -C iphone_sim_aarch install
}

build_iOS_aarch() {
    execute_and_check meson . iphone_aarch $THORVG_FLAGS --cross-file "$IPHONE_AARCH"
    execute_and_check ninja -C iphone_aarch install
}

build_macOS_x86() {
    execute_and_check meson . macos_x86_64 $THORVG_FLAGS --cross-file "$MACOS_X86_CROSS"
    execute_and_check ninja -C macos_x86_64 install
}

build_macOS_aarch() {
    execute_and_check meson . macos_aarch $THORVG_FLAGS --cross-file "$MACOS_AARCH"
    execute_and_check ninja -C macos_aarch install
}

initial_setup() {
    # Clean up from previous build if necessary
    rm -rf $BASE_DIR $IOS_BUILD_DIR $MACOS_BUILD_DIR ./artifacts/

    # Enter Thorvg and build for various architectures
    cd ./Thorvg/

    mkdir -p ./artifacts/include/

    cp $BINDINGS ./artifacts/include/thorvg_capi.h


# Create xcframework modulemap file
cat << EOF > "./artifacts/include/module.modulemap"
framework module Thorvg {
  umbrella header "thorvg_capi.h"
  export *
  module * { export * }
}
EOF

}

# ----------- END FUNCTIONS -----------

# Check for flags
while [[ "$1" =~ ^- ]]; do
    case $1 in
        -h | --help )
            display_help
            exit 0
            ;;
        -c | --clean )
            cleanup
            exit 0
        ;;
    esac
done

initial_setup

# Check if arguments are provided
if [ $# -gt 0 ]; then
    echo "Processing arguments..."
    
    # Counter to keep track of the loop iteration
    count=0

    frameworks=""

    arguments="$@"
    
    if [ "$arguments" = "all" ]; then
        arguments="iphone_sim_x86_64 iphone_aarch iphone_sim_aarch macos_aarch macos_x86_64"
    fi

    
    # Loop over each argument
    for arg in $arguments; do
        echo "Processing argument: $arg"
        frameworks="${frameworks} -framework ./artifacts/${arg}/Thorvg.framework "

        count=$((count+1))

        # Check the value of the argument
        if [ "$arg" = "iphone_sim_x86_64" ]; then
            build_iOS_sim_x86

        elif [ "$arg" = "iphone_aarch" ]; then
            build_iOS_aarch

        elif [ "$arg" = "iphone_sim_aarch" ]; then
            build_iOS_sim_aarch

        elif [ "$arg" = "macos_aarch" ]; then
            build_macOS_aarch

        elif [ "$arg" = "macos_x86_64" ]; then
            build_macOS_x86

        else
#            echo "Argument '$arg' is neither 'some_value' nor 'another_value'"
            display_help
            # Perform actions for other values or handle differently
        fi

        # Make the artifacts folder for each target
        mkdir -p ./artifacts/$arg

        execute_and_check lipo -create \
            "./$arg/src/libthorvg.a" \
            -o "./artifacts/$arg/libthorvg.a"

        FRAMEWORK_PATH="./artifacts/$arg/Thorvg.framework"
        mkdir -p $FRAMEWORK_PATH/Headers
        mkdir -p $FRAMEWORK_PATH/Modules

        mv ./artifacts/$arg/libthorvg.a $FRAMEWORK_PATH/Thorvg
        cp $BINDINGS $FRAMEWORK_PATH/Headers/
        cp ./artifacts/include/module.modulemap $FRAMEWORK_PATH/Modules/

        if [ $count -eq 1 ]; then
        # Set up the plist for the framework if first time looping
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
        fi
        
        # Check the value of the argument
        if [ "$arg" = "iphone_sim_x86_64" ]; then
            $PLISTBUDDY_EXEC -c "Add :CFBundleSupportedPlatforms:1 string iPhoneSimulator" $FRAMEWORK_PATH/Info.plist
                
        elif [ "$arg" = "iphone_aarch" ]; then
            $PLISTBUDDY_EXEC -c "Add :CFBundleSupportedPlatforms:1 string iPhoneOS" $FRAMEWORK_PATH/Info.plist

        elif [ "$arg" = "iphone_sim_aarch" ]; then
            $PLISTBUDDY_EXEC -c "Add :CFBundleSupportedPlatforms:1 string iPhoneSimulator" $FRAMEWORK_PATH/Info.plist

        elif [ "$arg" = "macos_aarch" ]; then
            $PLISTBUDDY_EXEC -c "Add :CFBundleSupportedPlatforms:1 string MacOSX" $FRAMEWORK_PATH/Info.plist

        elif [ "$arg" = "macos_x86_64" ]; then
            $PLISTBUDDY_EXEC -c "Add :CFBundleSupportedPlatforms:1 string MacOSX" $FRAMEWORK_PATH/Info.plist

        install_name_tool -id @rpath/Thorvg.framework/Thorvg $FRAMEWORK_PATH/Thorvg

        fi
    done

    execute_and_check xcodebuild -create-xcframework ${frameworks} -output "./artifacts/Thorvg.xcframework"

    # Creating Framework folder
    mkdir -p $BASE_DIR/Framework
    mkdir -p $BASE_DIR/Bindings

    execute_and_check cp -R ./artifacts/Thorvg.xcframework $BASE_DIR/Framework

    # Copy the swift bind file
    execute_and_check cp $WRAPPER_FILE $BASE_DIR/Bindings

    execute_and_check sed -i "" -E 's/[[:<:]]thorvgFFI[[:>:]]/Thorvg/g' $BASE_DIR/Bindings/$WRAPPER_FILE_NAME

    #clean up
    rm -rf ./artifacts

    mv $BASE_DIR ../
    
    display_success
else
    echo "$RED No arguments provided. $NC"

    display_help
fi
