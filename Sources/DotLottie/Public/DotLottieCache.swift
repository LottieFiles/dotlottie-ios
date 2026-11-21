//
//  DotLottieCache.swift
//  DotLottie
//

import Foundation

/// Caching policy for downloading animation files from the web.
public enum DotLottieCachePolicy {
    /// Caching is enabled (uses in-memory NSCache and disk cache).
    case enabled
    /// Caching is disabled; always fetch directly from network.
    case disabled
}

/// Thread-safe caching utility for animation assets downloaded via URL.
public final class DotLottieCache: @unchecked Sendable {
    public static let shared = DotLottieCache()

    private let memoryCache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.dotlottie.cache", attributes: .concurrent)

    /// Global cache policy (defaults to .enabled)
    public var cachePolicy: DotLottieCachePolicy = .enabled

    private var cacheDirectoryURL: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("DotLottieCache", isDirectory: true)
    }

    public init() {
        if let cacheDirectoryURL {
            try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
    }

    /// Retrieve cached animation data for a URL if available.
    public func get(for url: URL) -> Data? {
        guard cachePolicy == .enabled else { return nil }
        let key = cacheKey(for: url)

        // Check in-memory cache first
        if let data = memoryCache.object(forKey: key as NSString) {
            return data as Data
        }

        // Check disk cache
        if let fileURL = diskFileURL(for: url), fileManager.fileExists(atPath: fileURL.path) {
            if let data = try? Data(contentsOf: fileURL) {
                memoryCache.setObject(data as NSData, forKey: key as NSString)
                return data
            }
        }

        return nil
    }

    /// Store animation data into in-memory and disk cache.
    public func set(_ data: Data, for url: URL) {
        guard cachePolicy == .enabled else { return }
        let key = cacheKey(for: url)

        memoryCache.setObject(data as NSData, forKey: key as NSString)

        queue.async(flags: .barrier) { [weak self] in
            guard let self, let fileURL = self.diskFileURL(for: url) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Clear all items from both in-memory and disk cache.
    public func clearCache() {
        memoryCache.removeAllObjects()
        queue.sync(flags: .barrier) { [weak self] in
            guard let self, let cacheDirectoryURL = self.cacheDirectoryURL else { return }
            try? self.fileManager.removeItem(at: cacheDirectoryURL)
            try? self.fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private func cacheKey(for url: URL) -> String {
        return url.absoluteString
    }

    private func diskFileURL(for url: URL) -> URL? {
        guard let cacheDirectoryURL else { return nil }
        // Use base64 encoding to generate safe unique filename from URL string
        let filename = Data(url.absoluteString.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return cacheDirectoryURL.appendingPathComponent(filename)
    }
}
