//
//  Errors.swift
//
//
//  Created by Sam on 24/01/2024.
//

import Foundation

enum AnimationLoadErrors: Error {
    case loadAnimationDataError
    case loadFromPathError
    case convertToStringError
}

enum PlayerErrors: Error {
    case setFrameError
    case resizeError
    case stopError
    case pauseError
    case playError
}

enum FileErrors : Error {
    case invalidFileExtension
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
    case invalidURL
}
