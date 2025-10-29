//
//  Utils.swift
//
//
//  Created by Sam on 30/10/2023.
//

import Foundation

/// Fetches JSON or .lottie from requested URL.
/// - Parameter url: Web URL to the animation.
/// - Throws: invalidServerResponse
/// - Returns: Data object from the response
func fetchFileFromURL(url: URL) async throws -> Data {
    let session = URLSession.shared
    
    let (data, response) = try await session.data(from: url)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw NetworkingErrors.invalidServerResponse
    }
    
    return data
}


/// Attempts to retrieve animation from the main bundle.
/// - Parameters:
///   - animationName: Name of the animation asset.
///   - extensionName: Extension of the animation asset.
///   - bundle: Bundle of the animation asset.
/// - Throws: couldNotExportFromBundle, fileNotFound.
/// - Returns: The data.
func fetchFileFromBundle(animationName: String, extensionName: String, bundle: Bundle) throws -> Data {
    if let fileURL = bundle.url(forResource: animationName, withExtension: extensionName) {
        guard let fileContents = try? Data(contentsOf: fileURL) else {
            throw FetchErrors.couldNotExportFromBundle(animationName: animationName)
        }
        return (fileContents);
    }
    throw FetchErrors.fileNotFound(animationName: animationName, extensionName: extensionName)
}

/// Retrieve .json from a file written to disk.
/// ⚠️: If the animation contained assets, they will not be inlined in the returned JSON.
/// - Parameter url: Local URL on disk pointing to animation.
/// - Throws: fileNotFound.
/// - Returns: Stringified file data.
func getAnimationDataFromFile(at url: URL) throws -> String {
    do {
        let filedata = try String(contentsOf: url)
        
        return filedata
    } catch {
        throw FileErrors.fileNotFound(path: url.absoluteString)
    }
}


/// Returns a tuple containing the width, height of the animation at the filePath
/// - Parameter filePath: Path on disk to animation data.
/// - Throws: widthHeightNotFound
/// - Returns: (width, height) of the animation.
func getAnimationWidthHeight(filePath: URL) throws -> (UInt32, UInt32) {
    do {
        let animationData = try getAnimationDataFromFile(at: filePath)
        
        return try getAnimationWidthHeight(animationData: animationData)
    } catch let error {
        throw error
    }
}

func getAnimationFramerate(filePath: URL) throws -> Int {
    do {
        let animationData = try getAnimationDataFromFile(at: filePath)
        
        return try getAnimationFramerate(animationData: animationData)
    } catch let error {
        throw error
    }
}

func getAnimationFramerate(animationData: String) throws -> Int {
    do {
        if let data = animationData.data(using: .utf8) {
            
            let decodedData = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers]) as? [String: Any]
            var framerate: Int? = 0
            
            if let fr = decodedData?["fr"] {
                framerate = fr as? Int
            }
            // Check if we managed to get the width and height
            if let checkedFr = framerate {
                return checkedFr
            }
        }
    } catch let error {
        throw error
    }
    
    throw FileErrors.framerateNotFound
}

/// Returns a tuple containing the width, height of the animationData.
/// If width or height are unfindable, result will be nil.
/// - Parameter animationData: Animation data.
/// - Throws: widthHeightNotFound.
/// - Returns: (width, height) of the animation.
func getAnimationWidthHeight(animationData: String) throws -> (UInt32, UInt32) {
    do {
        if let data = animationData.data(using: .utf8) {
            
            let decodedData = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers]) as? [String: Any]
            var aWidth: UInt32? = 0
            var aHeight: UInt32? = 0
            
            if let width = decodedData?["w"] {
                aWidth = width as? UInt32
            }
            if let height = decodedData?["h"] {
                aHeight = height as? UInt32
            }
            
            // Check if we managed to get the width and height
            if let aH = aHeight, let aW = aWidth {
                return (aH, aW)
            }
        }
    } catch let error {
        throw error
    }
    
    throw FileErrors.widthHeightNotFound
}


/// Verifies if the URL is valid.
/// - Parameter url: Web URL.
/// - Throws: invalidFileExtension
func verifyUrlType(url: String) throws {
    let stringCheck: NSString = NSString(string: url)
    
    if stringCheck.pathExtension.lowercased() != "json" &&
        stringCheck.pathExtension.lowercased() != "lot" &&
        stringCheck.pathExtension.lowercased() != "lottie" {
        throw FileErrors.invalidFileExtension
    }
}
