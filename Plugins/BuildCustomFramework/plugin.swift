import PackagePlugin
import Foundation

@main
struct BuildCustomFramework: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        print("🔨 DotLottie Custom Framework Builder")
        print("=" * 50)
        print("")

        // Get paths
        let packageDirectory = context.package.directory
        let configPath = packageDirectory.appending(["Configuration", "BuildConfig.json"])
        let validationScript = packageDirectory.appending(["Scripts", "validate-environment.sh"])
        let buildScript = packageDirectory.appending(["Scripts", "build-framework.sh"])
        let outputDir = packageDirectory.appending(["Sources", "DotLottieCore", "Custom"])

        // Parse command line arguments
        var useConfigPath = configPath
        var skipValidation = false

        var argIndex = 0
        while argIndex < arguments.count {
            let arg = arguments[argIndex]
            switch arg {
            case "--config":
                if argIndex + 1 < arguments.count {
                    useConfigPath = Path(arguments[argIndex + 1])
                    argIndex += 2
                } else {
                    throw PluginError.missingConfigPath
                }
            case "--skip-validation":
                skipValidation = true
                argIndex += 1
            case "--help", "-h":
                printHelp()
                return
            default:
                print("⚠️  Unknown argument: \(arg)")
                argIndex += 1
            }
        }

        // Step 1: Load and validate configuration
        print("📖 Loading configuration...")
        let config = try loadConfiguration(from: useConfigPath)
        print("   ✓ Configuration loaded from: \(useConfigPath.lastComponent)")
        print("")

        // Display configuration
        print("⚙️  Build Configuration:")
        print("   Features:")
        for (feature, enabled) in config.features.sorted(by: { $0.key < $1.key }) {
            let status = enabled ? "✓" : "✗"
            print("     \(status) \(feature)")
        }
        print("")

        // Step 2: Validate environment (unless skipped)
        if !skipValidation {
            print("🔍 Validating build environment...")
            try validateEnvironment(scriptPath: validationScript)
            print("   ✓ Environment validation passed")
            print("")
        } else {
            print("⚠️  Skipping environment validation (--skip-validation)")
            print("")
        }

        // Step 3: Request permission to write to package directory
        print("📝 Requesting permission to write custom framework...")
        print("   Output: \(outputDir)")
        print("")

        // Step 4: Build framework
        print("🔨 Starting framework build...")
        print("   This may take several minutes...")
        print("")

        let buildStartTime = Date()

        try buildFramework(
            scriptPath: buildScript,
            configPath: useConfigPath,
            outputPath: outputDir
        )

        let buildDuration = Date().timeIntervalSince(buildStartTime)
        let minutes = Int(buildDuration) / 60
        let seconds = Int(buildDuration) % 60

        print("")
        print("✅ Build completed successfully!")
        print("   Build time: \(minutes)m \(seconds)s")
        print("")

        // Step 5: Verify output
        let frameworkPath = outputDir.appending("DotLottiePlayer.xcframework")
        if FileManager.default.fileExists(atPath: frameworkPath.string) {
            print("📦 Custom framework created at:")
            print("   \(frameworkPath)")
            print("")

            // Get framework size
            if let size = try? getDirectorySize(path: frameworkPath) {
                print("📊 Framework size: \(formatBytes(size))")
                print("")
            }
        } else {
            throw PluginError.frameworkNotCreated
        }

        // Step 6: Show next steps
        print("=" * 50)
        print("🎉 Custom build complete!")
        print("")
        print("Next steps:")
        print("  1. Update your Package.swift binary target path:")
        print("     .binaryTarget(")
        print("         name: \"DotLottiePlayer\",")
        print("         path: \"./Sources/DotLottieCore/Custom/DotLottiePlayer.xcframework\"")
        print("     )")
        print("")
        print("  2. Or use as local dependency in your project:")
        print("     .package(path: \"/path/to/dotlottie-ios\")")
        print("")
        print("  3. To rebuild with different features:")
        print("     - Edit: Configuration/BuildConfig.json")
        print("     - Run: swift package plugin --allow-writing-to-package-directory build-custom-framework")
        print("")
        print("For more information, see CUSTOM_BUILDS.md")
        print("=" * 50)
    }

    // MARK: - Helper Functions

    private func loadConfiguration(from path: Path) throws -> BuildConfig {
        let data = try Data(contentsOf: URL(fileURLWithPath: path.string))
        let decoder = JSONDecoder()
        return try decoder.decode(BuildConfig.self, from: data)
    }

    private func validateEnvironment(scriptPath: Path) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath.string]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
            print(output)
        }

        if let error = String(data: errorData, encoding: .utf8), !error.isEmpty {
            print(error)
        }

        if process.terminationStatus != 0 {
            throw PluginError.validationFailed
        }
    }

    private func buildFramework(scriptPath: Path, configPath: Path, outputPath: Path) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            scriptPath.string,
            "--config", configPath.string,
            "--output", outputPath.string
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Read output in real-time
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading

        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print(output, terminator: "")
            }
        }

        errorHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let error = String(data: data, encoding: .utf8) {
                print(error, terminator: "")
            }
        }

        try process.run()
        process.waitUntilExit()

        // Clean up handlers
        outputHandle.readabilityHandler = nil
        errorHandle.readabilityHandler = nil

        if process.terminationStatus != 0 {
            throw PluginError.buildFailed
        }
    }

    private func getDirectorySize(path: Path) throws -> Int64 {
        let url = URL(fileURLWithPath: path.string)
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey]

        var totalSize: Int64 = 0

        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                if resourceValues.isRegularFile == true {
                    totalSize += Int64(resourceValues.totalFileAllocatedSize ?? 0)
                }
            }
        }

        return totalSize
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func printHelp() {
        print("""
        DotLottie Custom Framework Builder

        Build a custom DotLottiePlayer.xcframework with configurable features.

        USAGE:
            swift package plugin --allow-writing-to-package-directory build-custom-framework [OPTIONS]

        OPTIONS:
            --config <path>       Path to custom BuildConfig.json (default: Configuration/BuildConfig.json)
            --skip-validation     Skip environment validation (not recommended)
            --help, -h            Show this help message

        EXAMPLES:
            # Build with default configuration
            swift package plugin --allow-writing-to-package-directory build-custom-framework

        For more information, see CUSTOM_BUILDS.md
        """)
    }
}

// MARK: - Models

struct BuildConfig: Codable {
    let version: String
    let features: [String: Bool]
}

// MARK: - Errors

enum PluginError: Error, CustomStringConvertible {
    case validationFailed
    case buildFailed
    case frameworkNotCreated
    case missingConfigPath

    var description: String {
        switch self {
        case .validationFailed:
            return """
            ❌ Environment validation failed!

            Please ensure all prerequisites are installed:
              1. Rust toolchain (rustup, cargo)
              2. Rust nightly toolchain
              3. Xcode command line tools
              4. Initialized dotlottie-rs submodule

            Run './Scripts/validate-environment.sh' for detailed information.
            """
        case .buildFailed:
            return """
            ❌ Framework build failed!

            Check the error messages above for details.
            Common issues:
              - Missing Rust dependencies
              - Uninitialized submodule
              - Invalid feature configuration

            See CUSTOM_BUILDS.md for troubleshooting guidance.
            """
        case .frameworkNotCreated:
            return "❌ Framework was not created at expected location"
        case .missingConfigPath:
            return "❌ --config option requires a path argument"
        }
    }
}

// String repeat helper
extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}
