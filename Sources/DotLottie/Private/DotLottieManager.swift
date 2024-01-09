//
//  File.swift
//  
//
//  Created by Sam on 18/12/2023.
//

import Foundation

enum DotLottieManagerErrors: Error {
    case missingAnimationInsideManifest
    case invalidURL
    case missingManifestFile
}

class DotLottieManager {
    // id : path on disk
    private var filePaths: [String: URL] = [:]
    
    // path on disk
    private var manifestFilePath: URL?

    // Object representation of manifest
    public private(set) var manifest: ManifestModel?

    public private(set) var currentAnimationId: String = ""
    
    // If an error occurs whilst loading
    private var errorMessage: String?

    public func initFromWebUrl(url: URL) async throws {
        // Fetch the file data
        let urlBook = try await fetchDotLottieAndWriteToDisk(url: url)

        try loadDotLottiePipeline(urlBook: urlBook)
    }
    
    /// Initiliaze the DotLottieManager from an animation inside the main asset bundle.
    /// - Parameter assetName: Name of the animation inside the asset bundle.
    public func initFromBundle(assetName: String) throws {
        let fileData = try fetchFileFromBundle(animationName: assetName,
                                               extensionName: "lottie")
        let urlBook = try writeDotLottieToDisk(dotLottie: fileData, fileName: assetName)

        try loadDotLottiePipeline(urlBook: urlBook)
    }
    
    /// Initialize the DotLottieManager with the dotLottie information already written to disk.
    /// - Parameter urlBook: A dictionnary containg the id of the animation as key, and its path to disk as URL.
    private func loadDotLottiePipeline(urlBook: [String:URL]) throws {
        guard let manifestPath = urlBook["manifest"] else { throw DotLottieManagerErrors.missingManifestFile }
        
        // Extract out a ManifestModel
        let manifestObject = try extractManifest(manifestFilePath: manifestPath)
        
        // Set properties
        self.filePaths = urlBook        
        self.manifest = manifestObject
        self.manifestFilePath = urlBook["manifest"]
        
        // If theres a default animation set the current animation id to that
        if let aaId = self.manifest?.activeAnimationId {
            if containsAnimation(animationId: aaId) {
                self.currentAnimationId = aaId
            }
        } else if let manifest = self.manifest {
            if let firstAnimation =  manifest.animations.first {
                self.currentAnimationId = firstAnimation.id
            }
        }
    }
    
    /// Check if an animation is inside the loaded dotLottie.
    /// - Parameter animationId: Id of the animation, available from the manifest.json file of the dotLottie.
    /// - Returns: True if contains the animation, otherwise false
    public func containsAnimation(animationId: String) -> Bool {
        if filePaths[animationId] != nil {
            return true
        }
        
        return false
    }
    
    /// Get the playback settings of a specific animation.
    /// - Parameter animationId: Id of the animation.
    /// - Returns: ManifestAnimationModel object containing the playback settings of the desired animation. Constructed from information inside the manifest file.
    public func getPlaybackSettings(animationId: String) throws -> ManifestAnimationModel {
        if let manifest = self.manifest {
            for animation in manifest.animations {
                if animation.id == animationId {
                    return animation
                }
            }
        }
        
        throw DotLottieManagerErrors.missingAnimationInsideManifest
    }
    
    /// Get the playback settings of the current active animation.
    /// - Returns: ManifestAnimationModel object containing the playback settings of the current active animation. Constructed from information inside the manifest file.
    public func currentAnimationPlaybackSettings() throws -> ManifestAnimationModel {
        return try getPlaybackSettings(animationId: self.currentAnimationId)
    }

    /// Loads the next animation from the dotLottie.
    /// - Returns: ManifestAnimationModel object containing the playback settings of the n+1 animation. Constructed from information inside the manifest file.
    public func nextAnimation() throws -> ManifestAnimationModel {
        if let manifest = self.manifest {
            
            let index = manifest.animations.firstIndex { animation in
                if animation.id == self.currentAnimationId {
                    return true
                } else {
                    return false
                }
            }
            
            if var checkedIndex = index  {
                if checkedIndex < manifest.animations.count - 1 {
                    checkedIndex += 1
                    
                    self.currentAnimationId = manifest.animations[checkedIndex].id
                }
                
                return manifest.animations[checkedIndex]
            }
        }
        
        throw DotLottieManagerErrors.missingAnimationInsideManifest
    }
    
    /// Loads the previous animation from the dotLottie.
    /// - Returns: ManifestAnimationModel object containing the playback settings of the n-1 animation. Constructed from information inside the manifest file.
    public func prevAnimation() throws -> ManifestAnimationModel {
        if let manifest = self.manifest {
            
            let index = manifest.animations.firstIndex { animation in
                if animation.id == self.currentAnimationId {
                    return true
                } else {
                    return false
                }
            }
            
            if var checkedIndex = index  {
                if checkedIndex > 0 {
                    checkedIndex -= 1
                    
                    self.currentAnimationId = manifest.animations[checkedIndex].id
                }

                return manifest.animations[checkedIndex]
            }
        }
        
        throw DotLottieManagerErrors.missingAnimationInsideManifest
    }
    
    
    /// Set the current playing animation.
    /// - Parameter animationId: Desired animation to play.
    public func setActiveAnimation(animationId: String) throws {
        if !self.containsAnimation(animationId: animationId) {
            throw DotLottieManagerErrors.missingAnimationInsideManifest
        }
        
        self.currentAnimationId = animationId
    }
    
    
    /// Returns the path on disk to the desired animation.
    /// - Parameter animationId: Animation to search for.
    /// - Returns: URL to a path on disk where the animation data in .json format is located.
    public func getAnimationPath(_ animationId: String) throws -> URL {
        if !self.containsAnimation(animationId: animationId) {
            throw DotLottieManagerErrors.missingAnimationInsideManifest
        }

        return filePaths[animationId]!
    }
    
    
    /// Get the current active animation id.
    /// - Returns: Id of the animation.
    public func getCurrentAnimationId() -> String {
        return currentAnimationId
    }
}
