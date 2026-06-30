// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DotLottie",
    platforms: [.iOS(.v13), .macOS(.v11), .tvOS(.v13), .macCatalyst(.v13), .watchOS(.v7)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "DotLottie",
            targets: ["DotLottie", "DotLottiePlayer"]),
        .library(
            name: "DotLottiePlayer",
            targets: ["DotLottiePlayer"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "DotLottie",
            dependencies: [
                "DotLottiePlayer",
                .target(name: "WgpuNative", condition: .when(platforms: [.iOS, .macOS])),
            ],
            path: "Sources/DotLottie/"),
        .testTarget(
            name: "DotLottieTests",
            dependencies: ["DotLottie"],
            resources: [.process("Fixtures")]),
        .binaryTarget(
            name: "DotLottiePlayer",
            path: "./Sources/DotLottieCore/DotLottiePlayer.xcframework"
            // Use custom build
            //            path: "./Sources/DotLottieCore/Custom/DotLottiePlayer.xcframework"
        ),
        .binaryTarget(name: "WgpuNative", path: "./Sources/DotLottieCore/WgpuNative.xcframework"),
        // Custom Framework Builder Plugin
        .plugin(
            name: "BuildCustomFramework",
            capability: .command(
                intent: .custom(
                    verb: "build-custom-framework",
                    description: "Build DotLottiePlayer XCFramework with custom features"
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "Write custom-built XCFramework to Sources/DotLottieCore/Custom/"
                    )
                ]
            ),
            path: "Plugins/BuildCustomFramework"
        )
    ]
)
