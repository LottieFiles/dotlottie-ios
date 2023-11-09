//
//  Utils.swift
//  
//
//  Created by Sam on 30/10/2023.
//

import Foundation
import ZIPFoundation

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

func fetchDotLottieAndUnzip(url: URL, completion: @escaping (String?) -> Void) {
    let session = URLSession.shared
    
    do {
        try verifyUrlType(url: url.absoluteString)
    } catch {
        print("URL seems fishy 🐠")
        return ;
    }
    
    let task = session.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error: \(error)")
            //            completion(nil)
            return
        }
        
        if let data = data {
            do {
                let archive = try Archive(data: data, accessMode: .read)

                for entry in archive {
                    print(entry.path)
                    do {
                        if entry.path == "manifest.json" {
                            var txtData = Data()
                            _ = try archive.extract(entry) { data in
                                txtData.append(data)
                            }
                            
                            let v = String(decoding: txtData, as: UTF8.self)
                            
                            print(v)
                        }
                        
                        if entry.path.contains("animations") && entry.path.contains("json") {
                            var txtData = Data()
                            
                            _ = try archive.extract(entry) { data in
                                txtData.append(data)
                            }
                            
                            let v = String(decoding: txtData, as: UTF8.self)
                                
//                            print(v)
//                            dotLottieAnimationData = v
                            completion(v)
                        }
                    } catch {
                        print("Read Error")
                        completion(nil)
                    }
                }
            } catch {
                print("Archive error")
                completion(nil)
            }
        }
    }
    
    task.resume()
}

//func fetchDotLottieAndUnzip(url: String) {
//    let session = URLSession.shared
//    let urlObj = URL(string: url)
//
//    do {
//        try verifyUrlType(url: url)
//    } catch {
//        print("URL seems fishy 🐠")
//        return ;
//    }
//
//    if urlObj != nil {
//        /*---------DOWNLOADING---------- */
//        let downloadTask = session.downloadTask(with: URL(string: url)!) {
//            urlOrNil, responseOrNil, errorOrNil in
//            // check for and handle errors:
//            // * errorOrNil should be nil
//            // * responseOrNil should be an HTTPURLResponse with statusCode in 200..<299
//            if errorOrNil != nil || responseOrNil == nil {
//                print("Download .lottie error")
//
//                return ;
//            }
//
//            guard let fileURL = urlOrNil else { return }
//
//            do {
//                let documentsURL = try
//                FileManager.default.url(for: .documentDirectory,
//                                        in: .userDomainMask,
//                                        appropriateFor: nil,
//                                        create: false)
//                let savedURL = documentsURL.appendingPathComponent(fileURL.lastPathComponent)
//                try FileManager.default.moveItem(at: fileURL, to: savedURL)
//
//                print("Download and moved zip to -> \(savedURL)")
//
//                /*---------UNZIPPING---------- */
//                let fileManager = FileManager()
//
//                let currentWorkingPath = fileManager.currentDirectoryPath
//                var sourceURL = URL(fileURLWithPath: savedURL.absoluteString)
//                //                sourceURL.appendPathComponent("archive.zip")
//                var destinationURL = URL(fileURLWithPath: currentWorkingPath)
//                destinationURL.appendPathComponent("directory")
//                do {
//                    try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
//                    try fileManager.unzipItem(at: sourceURL, to: destinationURL)
//
//                    let items = try fileManager.contentsOfDirectory(atPath: destinationURL.absoluteString)
//
//                    for item in items {
//                        print("Found \(item)")
//                    }
//                } catch {
//                    print("Extraction of ZIP archive failed with error:\(error)")
//                }
//            } catch {
//                print ("file error: \(error)")
//            }
//        }
//
//        downloadTask.resume()
//    }
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
