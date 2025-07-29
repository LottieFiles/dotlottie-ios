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
    internal lazy var dotLottieObserver: DotLottieObserver? = DotLottieObserver(self)
    
    private let dotLottiePlayer: DotLottiePlayer
    public var WIDTH: UInt32 = 512
    public var HEIGHT: UInt32 = 512
    
    private var currFrame: Float = -1.0;
    
    private var hasRenderedFirstFrame = false
    
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
            throw AnimationLoadErrors.loadAnimationDataError
        }
    }
    
    func loadDotlottieData(data: Data, width: Int, height: Int) throws {
        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)
        
        if (!dotLottiePlayer.loadDotlottieData(fileData: data, width: self.WIDTH, height: self.HEIGHT)) {
            throw AnimationLoadErrors.loadAnimationDataError
        }
    }
    
    public func loadAnimationPath(animationPath: String, width: Int, height: Int) throws {
        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)
        
        if (!dotLottiePlayer.loadAnimationPath(animationPath: animationPath,
                                               width: self.WIDTH,
                                               height: self.HEIGHT)) {
            throw AnimationLoadErrors.loadFromPathError
        }
    }
    
    public func loadAnimation(animationId: String, width: Int, height: Int) throws {
        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)
        
        if (!dotLottiePlayer.loadAnimation(animationId: animationId,
                                           width: self.WIDTH,
                                           height: self.HEIGHT)) {
            throw AnimationLoadErrors.loadFromPathError
        }
    }
    
    public func render() -> Bool {
        dotLottiePlayer.render()
    }
    
    public func tick() -> CGImage? {
        if (!self.isLoaded()) {
            return nil
        }
        
        let tick = dotLottiePlayer.tick()
        
        if tick || !hasRenderedFirstFrame || currFrame != dotLottiePlayer.currentFrame() {
            self.currFrame = dotLottiePlayer.currentFrame()
            
            hasRenderedFirstFrame = true
            
            _ = dotLottiePlayer.render()
            
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
        dotLottiePlayer.config()
    }
    
    public func totalFrames() -> Float {
        dotLottiePlayer.totalFrames()
    }
    
    @discardableResult
    public func setFrame(no: Float32) -> Bool {
        dotLottiePlayer.setFrame(no: no)
    }
    
    public func currentFrame() -> Float {
        dotLottiePlayer.currentFrame()
    }
    
    public func loopCount() -> Int {
        Int(dotLottiePlayer.loopCount())
    }
    
    public func isLoaded() -> Bool {
        dotLottiePlayer.isLoaded()
    }
    
    public func isPlaying() -> Bool {
        dotLottiePlayer.isPlaying()
    }
    
    public func isPaused() -> Bool {
        dotLottiePlayer.isPaused()
    }
    
    public func isStopped() -> Bool {
        dotLottiePlayer.isStopped()
    }
    
    public func isComplete() -> Bool {
        let complete = dotLottiePlayer.isComplete()
                
        return complete
    }
    
    public func markers() -> [Marker] {
        dotLottiePlayer.markers()
    }
    
    public func play() -> Bool {
        let play = dotLottiePlayer.play()
        
        return play
    }
    
    public func pause() -> Bool {
        let pause = dotLottiePlayer.pause()
        
        return pause
    }
    
    public func stop() -> Bool {
        let stop =  dotLottiePlayer.stop()

        return stop
    }
    
    public func resize(width: Int, height: Int) throws {
        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)
        
        if (!dotLottiePlayer.resize(width: self.WIDTH, height: self.HEIGHT)) {
            throw PlayerErrors.resizeError
        }
    }
    
    public func stateMachineLoad(id: String) -> Bool {
        dotLottiePlayer.stateMachineLoad(stateMachineId: id)
    }
    
    public func stateMachineLoadData(_ data: String) -> Bool {
        dotLottiePlayer.stateMachineLoadData(stateMachine: data)
    }
    
    public func stateMachineStart(openUrl: OpenUrl) -> Bool {
        let started = dotLottiePlayer.stateMachineStart(openUrl: openUrl)
                
        return started
    }
    
    public func stateMachineStop() -> Bool {
        return dotLottiePlayer.stateMachineStop()
    }
    
    public func stateMachinePostEvent(event: Event) -> Int32 {
        let ret = dotLottiePlayer.stateMachinePostEvent(event: event)
        
        return ret
    }
    
    public func stateMachineFire(event: String) {
        dotLottiePlayer.stateMachineFireEvent(event: event)
    }
    
    public func stateMachineSubscribe(observer: StateMachineObserver) -> Bool {
        dotLottiePlayer.stateMachineSubscribe(observer: observer)
    }
    
    public func stateMachineFrameworkSubscribe(observer: StateMachineObserver) -> Bool {
        dotLottiePlayer.stateMachineFrameworkSubscribe(observer: observer)
    }
    
    public func stateMachineUnSubscribe(oberserver: StateMachineObserver) -> Bool {
        dotLottiePlayer.stateMachineUnsubscribe(observer: oberserver)
    }
    
    
    public func stateMachineFrameworkUnsubscribe(observer: StateMachineObserver) -> Bool {
        dotLottiePlayer.stateMachineFrameworkUnsubscribe(observer: observer)
    }
    
    public func stateMachineFrameworkSetup() -> [String] {
        dotLottiePlayer.stateMachineFrameworkSetup()
    }
    
    public func getLayerBounds(layerName: String) -> [Float] {
        dotLottiePlayer.getLayerBounds(layerName: layerName)
    }
    
    public func stateMachineCurrentState() -> String {
        dotLottiePlayer.stateMachineCurrentState()
    }
    
    public func duration() -> Float32 {
        return dotLottiePlayer.duration()
    }
    
    public func clear() {
        dotLottiePlayer.clear()
    }
    
    public func setSlots(_ slots: String) -> Bool {
        dotLottiePlayer.setSlots(slots: slots);
    }
    
    public func setTheme(_ themeId: String) -> Bool {
        dotLottiePlayer.setTheme(themeId: themeId)
    }
    
    public func setThemeData(_ themeData: String) -> Bool {
        dotLottiePlayer.setThemeData(themeData: themeData)
    }
    
    public func resetTheme() -> Bool {
        dotLottiePlayer.resetTheme();
    }
    
    public func activeThemeId() -> String {
        dotLottiePlayer.activeThemeId()
    }
    
    public func activeAnimationId() -> String {
        dotLottiePlayer.activeAnimationId()
    }
    
    public func stateMachineSetNumericInput(key: String, value: Float) -> Bool {
        dotLottiePlayer.stateMachineSetNumericInput(key: key, value: value)
    }
    
    public func stateMachineSetStringInput(key: String, value: String) -> Bool {
        dotLottiePlayer.stateMachineSetStringInput(key: key, value: value)
    }
    
    public func stateMachineSetBooleanInput(key: String, value: Bool) -> Bool {
        dotLottiePlayer.stateMachineSetBooleanInput(key: key, value: value)
    }
}
