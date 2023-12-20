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
    case framerateNotFound
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
    case missingManifest
}

/// Fetches the .lottie from the URL and attempts to write the file contents to disk.
/// - Parameter url: Web URL to the animation
/// - Throws: failedToWriteToDisk, missingAnimations
/// - Returns: URL book containing the id of the animation and its path on disk.
func fetchDotLottieAndWriteToDisk(url: URL) async throws -> [String:URL] {
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

        if let fileNameSubstring = url.lastPathComponent.split(separator: ".lottie").first {
            let fileName = String(fileNameSubstring)
            let urlBook = try writeDotLottieToDisk(dotLottie: data, fileName: fileName)
        
            return urlBook
        } else {
            let urlBook = try writeDotLottieToDisk(dotLottie: data, fileName: UUID().uuidString)
            
            return urlBook
        }
        
    } catch let error {
        throw error
    }
}

// MARK - Extract Manifest

/// Extracts manifest file from data and builds the ManifestModel object from it.
/// - Parameter dotLottie: Data of the .lottie file.
/// - Throws: missingManifest
/// - Returns: ManifestModel object.
func extractManifest(dotLottie: Data) throws -> ManifestModel {
    do {
        // Attempt to read .lottie file
        let archive = try Archive(data: dotLottie, accessMode: .read)
        
        for entry in archive {
            if entry.path == "manifest.json" {
                var txtData = Data()
                
                _ = try archive.extract(entry) { data in
                    txtData.append(data)
                }

                let decoder = JSONDecoder()
                let jsonData = try decoder.decode(ManifestModel.self, from: txtData)
                
                return jsonData
            }
        }
    } catch let error {
        throw error
    }
    
    throw DotLottieErrors.missingManifest
}

func extractManifest(manifestFilePath: URL) throws -> ManifestModel {
    let fileData = try Data(contentsOf: manifestFilePath)
    let decoder = JSONDecoder()
    let jsonData = try decoder.decode(ManifestModel.self, from: fileData)
    
    return jsonData
}

/// Attempts to write doLottie contents to disk.
/// - Parameter dotLottie: Data of the .lottie file, fileName: Name of the animation without file extension.>
/// - Throws: failedToWriteToDisk, missingAnimations
/// - Returns: Dictionary containing the id of the animation as key, and its URL to the location its written to on disk
func writeDotLottieToDisk(dotLottie: Data, fileName: String) throws -> [String:URL] {
    do {
        let fileManager = FileManager.default
        var urlBook: [String:URL] = [:]
        
        // Get the URL for the Documents directory
        let documentsDirectory = try fileManager.url(for: .documentDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: false)
        let destinationURL = documentsDirectory
        let endPath = destinationURL.appendingPathComponent("animations/\(fileName)")

        var animationName = "dotLottie"
        
        // Attempt to read .lottie file
        let archive = try Archive(data: dotLottie, accessMode: .read)
        
        let manifestData = try extractManifest(dotLottie: dotLottie)

        try writeDataToFile(dataToWrite: JSONEncoder().encode(manifestData), filePath: endPath, fileName: "manifest.json")
        
        // Add the manifest to the url book
        urlBook["manifest"] = endPath.appendingPathComponent("manifest.json")
        
        for entry in archive {
            if entry.path.contains("animations") && entry.path.contains("json") {
                // Get filename without extensione
                if let url = URL(string: entry.path) {
                    animationName = url.deletingPathExtension().lastPathComponent
                }
                                
                // Add the animation name to the directory path under the animation directory
                var writeToURL = destinationURL
                writeToURL.appendPathComponent("animations/\(fileName)/\(animationName)/")

                // Add the animation to the url book
                urlBook[animationName] = try writeAnimationAndAssetsToDisk(entry: entry, archive: archive, destinationURL: writeToURL)
            }
        }

        return (urlBook)
    } catch let error {
        throw error
    }
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
func writeAnimationAndAssetsToDisk(entry: Entry, archive: Archive, destinationURL: URL) throws -> URL? {
    let fileManager = FileManager.default
    
    var txtData = Data()
//    var destinationURL = documentsDirectory
    
//    var animationName = "dotLottie"
    var animationFileName = "dotLottie.json"
    
    // Get filename without extension
//    if let url = URL(string: entry.path) {
//        animationName = url.deletingPathExtension().lastPathComponent
//    }
    
    // Get filename with extension
    animationFileName = entry.path.components(separatedBy: "/").last ?? "dotLottie.json"
    
    // Add the animation name to the directory path under the animation directory
//    destinationURL.appendPathComponent("animations/\(animationName)/")
    
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
    
    if stringCheck.pathExtension != "json" && stringCheck.pathExtension != "lottie" {
        throw FileErrors.invalidFileExtension
    }
}

/// Writes data to filePath
/// - Parameter: dataToWrite: Data
/// - Parameter: filePath: URL to write to
/// - Throws:
func writeDataToFile(dataToWrite: Data, filePath: URL, fileName: String) throws {
    let fileManager = FileManager.default
    let fileDestination = filePath.appendingPathComponent(fileName)

    do {
        if !fileManager.fileExists(atPath: fileDestination.path) {
            try fileManager.createDirectory(at: filePath, withIntermediateDirectories: true, attributes: nil)

            // Check if file exists at filePath
            if !fileManager.fileExists(atPath: fileDestination.path) {
                // If the file doesn't exist, create an empty file at that path
                if !fileManager.createFile(atPath: fileDestination.path,
                                           contents: dataToWrite,
                                           attributes: nil) {
                    throw WriteToFileError.writeFailure(description: "Failed to create file.")
                }
            }
        }
    } catch {
        throw WriteToFileError.writeFailure(description: error.localizedDescription)
    }
}
