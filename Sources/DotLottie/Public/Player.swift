//
//  Player.swift
//
//
//  Created by Sam on 11/12/2023.
//

import Foundation
import CoreImage
import DotLottiePlayer

class Player: ObservableObject {
    @Published public var playerState: PlayerState = .initial

    internal lazy var dotLottieObserver: DotLottieObserver? = DotLottieObserver(self)

    private let dotLottiePlayer: DotLottiePlayer
    private var WIDTH: UInt32 = 512
    private var HEIGHT: UInt32 = 512
    
    init(config: Config) {
        self.dotLottiePlayer = DotLottiePlayer(config: config)
    }
    
    deinit {
        self.destroy()
    }
    
    public func destroy() {
        if let ob = self.dotLottieObserver {
            self.dotLottiePlayer.unsubscribe(observer: ob)
            self.dotLottieObserver = nil
        }
    }
    
    public func loadAnimationData(animationData: String, width: Int, height: Int) throws {
        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)
        
        if (!dotLottiePlayer
            .loadAnimationData(animationData: animationData,
                               width: self.WIDTH,
                               height: self.HEIGHT)) {
            self.setPlayerState(state: .error)
            throw AnimationLoadErrors.loadAnimationDataError
        }
    }
    
    func loadDotlottieData(data: Data) throws {
        if (!dotLottiePlayer.loadDotlottieData(fileData: data, width: self.WIDTH, height: self.HEIGHT)) {
            self.setPlayerState(state: .error)
            throw AnimationLoadErrors.loadAnimationDataError
        }
    }
    
    public func loadAnimationPath(animationPath: String, width: Int, height: Int) throws {
        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)
        
        if (!dotLottiePlayer.loadAnimationPath(animationPath: animationPath,
                                               width: self.WIDTH,
                                               height: self.HEIGHT)) {
            self.setPlayerState(state: .error)
            throw AnimationLoadErrors.loadFromPathError
        }
    }
    
    public func loadAnimation(animationId: String, width: Int, height: Int) throws {
        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)
        
        if (!dotLottiePlayer.loadAnimation(animationId: animationId,
                                           width: self.WIDTH,
                                           height: self.HEIGHT)) {
            self.setPlayerState(state: .error)
            throw AnimationLoadErrors.loadFromPathError
        }
    }
    
    public func render() -> CGImage? {
        if (!self.isLoaded() || !dotLottiePlayer.render()) {
            return nil
        }
        
        let bitsPerComponent = 8
        let bytesPerRow = 4 * self.WIDTH
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let pixelData = UnsafeMutablePointer<UInt8>(bitPattern: UInt(dotLottiePlayer.bufferPtr()))
        
        if (pixelData != nil) {
            if let context = CGContext(data: pixelData, width: Int(self.WIDTH), height: Int(self.HEIGHT), bitsPerComponent: bitsPerComponent, bytesPerRow: Int(bytesPerRow), space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                if let newImage = context.makeImage() {
                    return newImage
                }
            }
        }
        return nil
    }
    
    public func subscribe(observer: Observer) {
        dotLottiePlayer.subscribe(observer: observer)
    }

    public func unsubscribe(observer: Observer) {
        dotLottiePlayer.unsubscribe(observer: observer)
    }

    public func manifest() -> Manifest? {
        return dotLottiePlayer.manifest()
    }
    
    public func bufferPointer() -> UInt64{
        return dotLottiePlayer.bufferPtr()
    }
    
    public func bufferLen() -> UInt64{
        return dotLottiePlayer.bufferLen()
    }
    
    public func setConfig(config: Config) {
        dotLottiePlayer.setConfig(config: config)
    }
    
    public func config() -> Config {
        return dotLottiePlayer.config()
    }
    
    public func totalFrames() -> Float {
        return dotLottiePlayer.totalFrames()
    }
    
    public func setFrame(no: Float32) -> Bool {
        return dotLottiePlayer.setFrame(no: no)
    }
    
    public func currentFrame() -> Float {
        return dotLottiePlayer.currentFrame()
    }
    
    public func loopCount() -> Int {
        return Int(dotLottiePlayer.loopCount())
    }
    
    public func isLoaded() -> Bool {
        return dotLottiePlayer.isLoaded()
    }
    
    public func isPlaying() -> Bool {
        return dotLottiePlayer.isPlaying()
    }
    
    public func isPaused() -> Bool {
        return dotLottiePlayer.isPaused()
    }
    
    public func isStopped() -> Bool {
        return dotLottiePlayer.isStopped()
    }
    
    public func isComplete() -> Bool {
        return self.dotLottiePlayer.isComplete()
    }
    
    public func markers() -> [Marker] {
        return self.dotLottiePlayer.markers()
    }
    
    public func play() {
        let _ = dotLottiePlayer.play()
        
        self.setPlayerState(state: .playing)
    }
    
    public func pause() {
        let _ = dotLottiePlayer.pause()

        self.setPlayerState(state: .paused)
    }
    
    public func stop() {
        let _ = dotLottiePlayer.stop()
        
        self.setPlayerState(state: .stopped)
    }
    
    public func resize(width: Int, height: Int) throws {
        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)
        
        if (!dotLottiePlayer.resize(width: self.WIDTH, height: self.HEIGHT)) {
            throw PlayerErrors.resizeError
        }
    }
    
    public func requestFrame() -> Bool {
        let frame = dotLottiePlayer.requestFrame()

        return self.setFrame(no: frame)
    }
       
    public func duration() -> Float32 {
        return dotLottiePlayer.duration()
    }
    
    public func clear() {
        dotLottiePlayer.clear()
    }
    
    public func setPlayerState(state: PlayerState) {
        DispatchQueue.main.async {
            self.playerState = state
        }
    }
}
