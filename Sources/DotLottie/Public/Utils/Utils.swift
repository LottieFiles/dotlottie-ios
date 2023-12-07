//
//  Utils.swift
//
//
//  Created by Sam on 30/10/2023.
//

import Foundation
import ZIPFoundation

enum WriteToFileError : Error {
    case writeFailure(description: String)
}

enum FileErrors : Error {
    case invalidFileExtension
    case dowloadFailed
    case fileNotFound(path: String)
    case widthHeightNotFound
}

enum FetchErrors: Error {
    case fileNotFound(animationName: String, extensionName: String)
    case couldNotExportFromBundle(animationName: String)
}

enum NetworkingErrors: Error {
    case invalidServerResponse
}

enum WriteErrors: Error {
    case failedToWriteToDisk
}

enum DotLottieErrors: Error {
    case missingAnimations
}

/// Fetches the .lottie from the URL and attempts to write the file contents to disk.
/// - Parameter url: Web URL to the animation
/// - Throws: failedToWriteToDisk, missingAnimations
/// - Returns: URL pointing to the location on disk the animation was written to.
func fetchDotLottieAndWriteToDisk(url: URL) async throws -> URL {
    // Verify if the URL is valid
    do {
        try verifyUrlType(url: url.absoluteString)
    } catch let error {
        print("URL is invalid.")
        throw error
    }
    
    // Fetch data
    do {
        let data = try await fetchFileFromURL(url: url)
        
        return try writeDotLottieToDisk(dotLottie: data)
    } catch let error {
        throw error
    }
}


/// Attempts to write doLottie contents to disk.
/// - Parameter dotLottie: Data of the .lottie file.
/// - Throws: failedToWriteToDisk, missingAnimations
/// - Returns: URL pointing to the location on disk to where the animation was written to.
func writeDotLottieToDisk(dotLottie: Data) throws -> URL {
    // Fetch data
    do {
        // Attempt to read .lottie file
        let archive = try Archive(data: dotLottie, accessMode: .read)
        
        for entry in archive {
            if entry.path == "manifest.json" {
                var txtData = Data()
                _ = try archive.extract(entry) { data in
                    txtData.append(data)
                }
                
                // The manifest
                _ = String(decoding: txtData, as: UTF8.self)
            }
            
            if entry.path.contains("animations") && entry.path.contains("json") {
                guard let path = try writeAnimationAndAssetsToDisk(entry: entry, archive: archive) else {
                    throw WriteErrors.failedToWriteToDisk
                }
                
                // For the moment we return straight away as we only support one animaion
                return path
            }
        }

    } catch let error {
        throw error
    }
    
    throw DotLottieErrors.missingAnimations
}


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
/// - Parameter animationName: Name of the animation asset.
/// - Throws: couldNotExportFromBundle, fileNotFound.
/// - Returns: The data.
func fetchFileFromBundle(animationName: String, extensionName: String) throws -> Data {
    if let fileURL = Bundle.main.url(forResource: animationName, withExtension: extensionName) {
        guard let fileContents = try? Data(contentsOf: fileURL) else {
            throw FetchErrors.couldNotExportFromBundle(animationName: animationName)
        }
        return (fileContents);
    }
    throw FetchErrors.fileNotFound(animationName: animationName, extensionName: extensionName)
}


/// Loops through an entry of the .lottie archive and write the animation along with its image assets to disk.
/// - Parameters:
///   - entry: An Entry of the archive we want to extract.
///   - archive: The Zip archive.
/// - Throws: writeFailure
/// - Returns: URL on disk pointing to where the animation and assets were written to.
func writeAnimationAndAssetsToDisk(entry: Entry, archive: Archive) throws -> URL? {
    let fileManager = FileManager.default
    
    // Get the URL for the Documents directory
    let documentsDirectory = try fileManager.url(for: .documentDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: false)
    
    var txtData = Data()
    var destinationURL = documentsDirectory
    
    var animationName = "dotLottie"
    var animationFileName = "dotLottie.json"
    
    // Get filename without extension
    if let url = URL(string: entry.path) {
        animationName = url.deletingPathExtension().lastPathComponent
    }
    
    // Get filename with extension
    animationFileName = entry.path.components(separatedBy: "/").last ?? "dotLottie.json"
    
    // Add the animation name to the directory path under the animation directory
    destinationURL.appendPathComponent("animations/\(animationName)/")
    
    // Add filename with its extension to the destination url
    var fileDestination = destinationURL
    fileDestination.appendPathComponent(animationFileName)
    
    do {
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Extract JSON to variable for parsing
        _ = try archive.extract(entry) { data in
            txtData.append(data)
        }
        
        // Write the animation (entry) to disk
        if !fileManager.fileExists(atPath: "\(fileDestination)") {
            try txtData.write(to: fileDestination)
        }
        
        let v = String(decoding: txtData, as: UTF8.self)
        
        // Deserialize JSON
        let decodedData = try JSONSerialization.jsonObject(with: v.data(using: .utf8)!, options: [.mutableContainers]) as? [String: Any]
        
        // Loop over assets of the animation and write them to disk
        // Assets will be placed next to the .json so ThorVG can find them
        if let assetsArray = decodedData?["assets"] as? NSArray {
            // Iterate over each asset in the array
            for index in 0..<assetsArray.count {
                if let asset = assetsArray[index] as? NSDictionary {
                    if let name = asset["p"] as? String {
                        
                        // Check if the images are in the .lottie zip
                        guard let imageEntry = archive["images/\(name)"] else {
                            return nil
                        }
                        
                        var imgData = Data()
                        
                        // Extract image data
                        _ = try archive.extract(imageEntry) { data in
                            imgData.append(data)
                        }
                        
                        var imgPath = destinationURL
                        
                        imgPath.appendPathComponent(name)
                        
                        // Write to disk
                        if !fileManager.fileExists(atPath: imgPath.absoluteString) {
                            try imgData.write(to: imgPath)
                        }
                    }
                }
            }
        }
        
        return (fileDestination)
    } catch let error {
        throw WriteToFileError.writeFailure(description: "Error writing to disk: \(error)")
    }
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
    
    if stringCheck.pathExtension != "json" && stringCheck.pathExtension != "lottie" {
        throw FileErrors.invalidFileExtension
    }
}
