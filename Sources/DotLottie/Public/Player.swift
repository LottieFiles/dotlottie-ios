//
//  File.swift
//
//
//  Created by Sam on 11/12/2023.
//

import Foundation
import CoreImage
import DotLottiePlayer

enum AnimationLoadErrors: Error {
    case loadAnimationDataError
    case loadFromPathError
}

class Player {
    private let dotLottiePlayer: DotLottiePlayer
    private var WIDTH: UInt32 = 512
    private var HEIGHT: UInt32 = 512
    private var isLoaded = false
    
    init() {
        dotLottiePlayer = DotLottiePlayer()
    }
    
    public func loadAnimation(animationData: String, width: Int, height: Int) throws {
        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)
        
        let ret = dotLottiePlayer
            .loadAnimation(animationData: animationData,
                           width: self.WIDTH,
                           height: self.HEIGHT)
        
        if (!ret) {
            throw AnimationLoadErrors.loadAnimationDataError
        }

        self.isLoaded = true
    }
    
    public func loadAnimationFromPath(animationPath: String, width: Int, height: Int) throws {
        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)

        let ret = dotLottiePlayer.loadAnimationFromPath(path: animationPath, width: self.WIDTH, height: self.HEIGHT)

        if (!ret) {
            throw AnimationLoadErrors.loadFromPathError
        }

        self.isLoaded = true
    }
    
    public func render() -> CGImage? {
        // Only render images when we've loaded animation data
        if (!isLoaded) {
            return nil
        }
        
        let bitsPerComponent = 8
        let bytesPerRow = 4 * self.WIDTH
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let pixelData = UnsafeMutablePointer<UInt8>(bitPattern: UInt(dotLottiePlayer.getBuffer()))
        
        if (pixelData != nil) {
            if let context = CGContext(data: pixelData, width: Int(self.WIDTH), height: Int(self.HEIGHT), bitsPerComponent: bitsPerComponent, bytesPerRow: Int(bytesPerRow), space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                if let newImage = context.makeImage() {
                    return newImage
                }
            }
        }
        return nil
    }
    
    func totalFrames() -> Float {
        return dotLottiePlayer.getTotalFrame()
    }

    func frame(no: Float32) {
        dotLottiePlayer.frame(no: no)
    }
    
    func currentFrame() -> Float32 {
        return dotLottiePlayer.getCurrentFrame()
    }
    
    func duration() -> Float32 {
        return dotLottiePlayer.getDuration()
    }
    
    func clear() {
        dotLottiePlayer.clear()
    }
}
