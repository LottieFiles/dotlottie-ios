//
//  Utils.swift
//  
//
//  Created by Sam on 30/10/2023.
//

import Foundation

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

