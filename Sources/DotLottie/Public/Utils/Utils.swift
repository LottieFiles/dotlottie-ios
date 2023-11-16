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

func fetchJsonFromUrl(url: URL, completion: @escaping (String?) -> Void) {
    let session = URLSession.shared
    
    let task = session.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error: \(error)")
            completion(nil)
            return
        }
        
        if let data = data, let string = String(data: data, encoding: .utf8) {
            completion(string)
        } else {
            completion(nil)
        }
    }
    
    task.resume()
}

func fetchJsonFromBundle(animation_name: String, completion: @escaping (String?) -> Void) {
    if let fileURL = Bundle.main.url(forResource: animation_name, withExtension: "json") {
        if let fileContents = try? String(contentsOf: fileURL) {
            completion(fileContents);
            return ;
        }
    }
    completion(nil);
}

private func getImageDataFromZip(fileName: String, archive: Archive) -> String {
    guard let entry = archive["images/\(fileName)"] else {
        return ""
    }
    
    var txtData = Data()
    var v = ""
    
    do {
        _ = try archive.extract(entry) { data in
            
            txtData.append(data)
            
            v = txtData.base64EncodedString()
            
            v = "data:image/png;base64," + v
        }
    } catch {
        print("ERROR EXTRACTING IMAGE DATA")
    }
    
    return v
}

func writeImageToFile(imageName: String, archive: Archive) -> URL? {
    let fileManager = FileManager()
    
    let currentWorkingPath = fileManager.currentDirectoryPath
    
    guard let entry = archive["images/\(imageName)"] else {
        print("Error inflating image file: Invalid image name inside of .lottie")
        
        return nil
    }
    
    var destinationURL = URL(fileURLWithPath: currentWorkingPath)
    destinationURL.appendPathComponent(imageName)
    
    do {
        let _ = try archive.extract(entry, to: destinationURL)
        
        print("Extracted image to \(destinationURL)")
    } catch {
        print("Extracting entry from archive failed with error:\(error)")
    }
    
    return destinationURL
}

func writeAnimationAndAssetsToDisk(entry: Entry, archive: Archive) throws -> String {
    let fileManager = FileManager()
    let currentWorkingPath = fileManager.currentDirectoryPath
    var txtData = Data()
    var destinationURL = URL(fileURLWithPath: currentWorkingPath)
    
    var animationName = "dotLottie"
    var animationFileName = "dotLottie.json"
    
    if let url = URL(string: entry.path) {
        animationName = url.deletingPathExtension().lastPathComponent
        
        print(animationName) // This will print: animation1
    }
    
    animationFileName = entry.path.components(separatedBy: "/").last ?? "dotLottie.json"
    
    // Add the animation name to the directory path
    // i.e: ..data/animations/animation1.json
    // Todo: Prepend file name before animations
    destinationURL.appendPathComponent("animations/\(animationName)/")
    
    // Create file destination URL
    var fileDestination = destinationURL
    fileDestination.appendPathComponent(animationFileName)
    
    print(">> Destination URL \(destinationURL)")
    
    do {
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: destinationURL.path) {
            print(">>>> Creating dir")
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Extract JSON to variable for parsing
        _ = try archive.extract(entry) { data in
            txtData.append(data)
        }
        
        // Write to disk
        if !fileManager.fileExists(atPath: "\(fileDestination)") {
            print(">>> Writing \(animationFileName) to file: \(fileDestination.absoluteString)")
            
            try txtData.write(to: fileDestination)
        }
        
        let v = String(decoding: txtData, as: UTF8.self)
        
        // Deserialize JSON
        let decodedData = try JSONSerialization.jsonObject(with: v.data(using: .utf8)!, options: [.mutableContainers]) as? [String: Any]
        
        // Loop over assets of the animation
        if let assetsArray = decodedData?["assets"] as? NSArray {
            //            Iterate over each asset in the array
            for index in 0..<assetsArray.count {
                if let asset = assetsArray[index] as? NSDictionary {
                    if let name = asset["p"] as? String {
                        
                        // Write images to disk too
                        guard let imageEntry = archive["images/\(name)"] else {
                            return ""
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
                            print(">>> Writing \(name) to file: \(imgPath.absoluteString)")
                            
                            try imgData.write(to: imgPath)
                        }
                    }
                }
            }
        }
        
        return (fileDestination.absoluteString)
    } catch let error {
        throw WriteToFileError.writeFailure(description: "Error writing to disk: \(error)")
    }
}

func fetchDotLottieAndUnzipAndWriteToDisk(url: URL, completion: @escaping (String?) -> Void) {
    let session = URLSession.shared
    
    do {
        try verifyUrlType(url: url.absoluteString)
    } catch {
        print("URL is incorrect.")
        completion(nil)
        return
    }
    
    let task = session.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error fetch data: \(error)")

            completion(nil)
            return
        }
        
        if let data = data {
            do {
                let archive = try Archive(data: data, accessMode: .read)
                
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
                        let path = try writeAnimationAndAssetsToDisk(entry: entry, archive: archive)
                        
                        completion(path)
                    }
                }
            } catch let error {
                print("\(error)")
                
                completion(nil)
                return

            }
        }
    }
    
    task.resume()
}

//func fetchDotLottieAndUnzip(url: URL, completion: @escaping (String?) -> Void) {
//    let session = URLSession.shared
//
//    do {
//        try verifyUrlType(url: url.absoluteString)
//    } catch {
//        print("URL seems fishy 🐠")
//        return ;
//    }
//
//    let task = session.dataTask(with: url) { data, response, error in
//        if let error = error {
//            print("Error: \(error)")
//            return
//        }
//
//        if let data = data {
//            do {
//                let archive = try Archive(data: data, accessMode: .read)
//
//                for entry in archive {
//                    do {
//                        if entry.path == "manifest.json" {
//                            var txtData = Data()
//                            _ = try archive.extract(entry) { data in
//                                txtData.append(data)
//                            }
//
//                            // The manifest
//                            _ = String(decoding: txtData, as: UTF8.self)
//                        }
//
//                        if entry.path.contains("animations") && entry.path.contains("json") {
//                            var txtData = Data()
//
//                            _ = try archive.extract(entry) { data in
//                                txtData.append(data)
//                            }
//
//                            let v = String(decoding: txtData, as: UTF8.self)
//
//                            var decodedData = try JSONSerialization.jsonObject(with: v.data(using: .utf8)!, options: [.mutableContainers]) as? [String: Any]
//
//                            if let assetsArray = decodedData?["assets"] as? NSArray {
//                                // Create a mutable copy of the assets array
//                                let mutableAssetsArray = NSMutableArray(array: assetsArray)
//
//                                // Iterate over each asset in the array
//                                for index in 0..<mutableAssetsArray.count {
//                                    if let asset = mutableAssetsArray[index] as? NSMutableDictionary {
//                                        // Modify the value of a specific key inside each asset
//                                        if let name = asset["p"] as? String {
//                                            asset["e"] = 1
//                                            asset["p"] = getImageDataFromZip(fileName: name, archive: archive)
//                                        }
//                                    }
//                                }
//
//                                decodedData?["assets"] = mutableAssetsArray
//                            }
//
//                            // Convert the modified dictionary back to JSON data
//                            let modifiedJsonData = try JSONSerialization.data(withJSONObject: decodedData!)
//
//                            // Convert JSON data to a string
//                            if let modifiedJsonString = String(data: modifiedJsonData, encoding: .utf8) {
//
//                                //                                print(modifiedJsonString)
//
//                                completion(modifiedJsonString)
//                            } else {
//                                print("Error converting JSON data to a string.")
//                                completion(nil)
//                            }
//                        }
//                    } catch {
//                        print("Read Error")
//                        completion(nil)
//                    }
//                }
//            } catch {
//                print("Archive error")
//                completion(nil)
//            }
//        }
//    }
//
//    task.resume()
//}

func verifyUrlType(url: String) throws -> Void {
    let stringCheck: NSString = NSString(string: url)
    
    if stringCheck.pathExtension != "json" && stringCheck.pathExtension != "lottie" {
        throw FileErrors.invalidFileExtension
    }
}

enum FileErrors : Error {
    case invalidFileExtension
    case dowloadFailed
}
