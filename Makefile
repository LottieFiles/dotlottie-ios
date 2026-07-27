# dotlottie-ios Makefile
# Owns the build process for DotLottiePlayer.xcframework from deps/dotlottie-rs

.PHONY: all help apple apple-webgpu apple-clean apple-setup clean setup

# Default target
all: help

# Include platform makefiles
include make/apple.mk

help:
	@echo "dotlottie-ios Build System"
	@echo "=========================="
	@echo ""
	@echo "Apple Targets:"
	@echo "  make apple                   - Build + install DotLottiePlayer.xcframework"
	@echo "                                 (WebGPU + watchOS included by default)"
	@echo "  make apple-build             - Build only, stage under build/apple/ without installing into Sources/"
	@echo "  make apple-webgpu            - Alias for 'make apple' (WebGPU ships by default)"
	@echo "  make apple-ios               - Build iOS slices only"
	@echo "  make apple-macos             - Build macOS slices only"
	@echo "  make apple-watchos           - Build watchOS slices only"
	@echo "  make apple-ios-arm64         - Build iOS ARM64 (device)"
	@echo "  make apple-ios-sim-arm64     - Build iOS ARM64 simulator"
	@echo "  make apple-macos-arm64       - Build macOS ARM64"
	@echo "  make apple-macos-x86_64      - Build macOS x86_64"
	@echo ""
	@echo "Setup / Clean:"
	@echo "  make apple-setup             - Install required Rust targets + pre-warm Cargo/wgpu-native caches"
	@echo "  make apple-clean             - Clean Apple build artifacts"
	@echo "  make clean                   - Clean all build artifacts"
	@echo ""
	@echo "Output (installed automatically by 'make apple'):"
	@echo "  Sources/DotLottieCore/DotLottiePlayer.xcframework"
	@echo "  Sources/DotLottieCore/WgpuNative.xcframework"
	@echo "  Sources/DotLottie/Public/dotlottie_player.h"
	@echo ""
	@echo "Override features:"
	@echo "  make apple FEATURES=tvg-webp,tvg-png,tvg-jpg"
	@echo ""

setup: apple-setup

clean: apple-clean
	@rm -rf build/
