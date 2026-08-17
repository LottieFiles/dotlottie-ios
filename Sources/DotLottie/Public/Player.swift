//
//  Player.swift
//
//
//  Created by Sam on 11/12/2023.
//

import Foundation
import CoreGraphics
import DotLottiePlayer

class Player: ObservableObject {
    private let dotLottiePlayer: DotLottiePlayer

    public var WIDTH: UInt32 = 512
    public var HEIGHT: UInt32 = 512
    
    // Software rendering buffer
    private var renderBuffer: UnsafeMutablePointer<UInt32>?
    private var bufferSize: Int = 0

    private var currFrame: Float = -1.0;
    
    private var hasRenderedFirstFrame = false
    
    private var hasResized = false
    
    init(config: Config, threads : Int? = nil) {
        if let threads = threads {
            self.dotLottiePlayer = DotLottiePlayer.withThreads(config: config, threads: UInt32(threads))
        } else {
            self.dotLottiePlayer = DotLottiePlayer(config: config)
        }
    }
    
    public func loadAnimationData(animationData: String, width: Int, height: Int) throws {
        try assertValidRenderSize(width: width, height: height)

        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)

        try allocateRenderBuffer()

        if (!dotLottiePlayer.loadAnimationData(animationData: animationData)) {
            throw AnimationLoadErrors.loadAnimationDataError
        }
    }

    func loadDotlottieData(data: Data, width: Int, height: Int) throws {
        try assertValidRenderSize(width: width, height: height)

        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)

        try allocateRenderBuffer()

        if (!dotLottiePlayer.loadDotlottieData(fileData: data)) {
            throw AnimationLoadErrors.loadAnimationDataError
        }
    }

    public func loadAnimationPath(animationPath: String, width: Int, height: Int) throws {
        try assertValidRenderSize(width: width, height: height)

        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)

        try allocateRenderBuffer()

        if (!dotLottiePlayer.loadAnimationPath(animationPath: animationPath)) {
            throw AnimationLoadErrors.loadFromPathError
        }
    }
    
    public func animationSize() -> CGSize {
        dotLottiePlayer.animationSize()
    }
    
    public func loadAnimation(animationId: String, width: Int, height: Int) throws {
        try assertValidRenderSize(width: width, height: height)

        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)

        try allocateRenderBuffer()

        if (!dotLottiePlayer.loadAnimation(animationId: animationId)) {
            throw AnimationLoadErrors.loadFromPathError
        }
    }
    
    public func render() -> Bool {
        dotLottiePlayer.render()
    }

    private func allocateRenderBuffer() throws {
        // Clean up existing buffer
        deallocateRenderBuffer()

        // Allocate new buffer
        bufferSize = Int(WIDTH * HEIGHT)
        renderBuffer = UnsafeMutablePointer<UInt32>.allocate(capacity: bufferSize)
        renderBuffer?.initialize(repeating: 0, count: bufferSize)

        // Configure software renderer
        guard let buffer = renderBuffer else {
            throw PlayerErrors.bufferAllocationError
        }

        if !dotLottiePlayer.setSoftwareTarget(
            buffer: buffer,
            width: WIDTH,
            height: HEIGHT,
            colorSpace: .abgr8888
        ) {
            deallocateRenderBuffer()
            throw PlayerErrors.rendererConfigurationError
        }
    }

    private func deallocateRenderBuffer() {
        if let buffer = renderBuffer {
            buffer.deinitialize(count: bufferSize)
            buffer.deallocate()
            renderBuffer = nil
            bufferSize = 0
        }
    }

    /// Advances playback by `dt` **milliseconds** (the core's tick contract)
    /// and returns the rendered frame, or nil if nothing changed.
    public func tick(dt: Float) -> CGImage? {
        if !self.isLoaded() {
            return nil
        }

        let tick = dotLottiePlayer.tick(dt: dt)

        // Software mode: create CGImage from buffer
        if tick || !hasRenderedFirstFrame || currFrame != dotLottiePlayer.currentFrame() || hasResized {
            self.currFrame = dotLottiePlayer.currentFrame()
            hasRenderedFirstFrame = true
            hasResized = false

            // Use Swift-managed buffer
            guard let pixelData = renderBuffer else {
                return nil
            }

            let bitsPerComponent = 8
            let bytesPerRow = 4 * Int(self.WIDTH)
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            if let context = CGContext(
                data: pixelData,
                width: Int(self.WIDTH),
                height: Int(self.HEIGHT),
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
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

    public func setConfig(config: Config) {
        dotLottiePlayer.setConfig(config: config)
    }
    
    public func config() -> Config {
        return Config(
            autoplay: dotLottiePlayer.getAutoplay(),
            loopAnimation: dotLottiePlayer.getLoop(),
            loopCount: dotLottiePlayer.getLoopCount(),
            mode: dotLottiePlayer.getMode(),
            speed: dotLottiePlayer.getSpeed(),
            useFrameInterpolation: dotLottiePlayer.getUseFrameInterpolation(),
            segment: dotLottiePlayer.getSegment() ?? [],
            backgroundColor: dotLottiePlayer.getBackgroundColor(),
            layout: dotLottiePlayer.getLayout(),
            marker: dotLottiePlayer.getActiveMarker() ?? ""
        )
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
        Int(dotLottiePlayer.currentLoopCount())
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
        dotLottiePlayer.isComplete()
    }
    
    public func markers() -> [Marker] {
        dotLottiePlayer.markers()
    }
    
    @discardableResult
    public func play() -> Bool {
        dotLottiePlayer.play()
    }
    
    @discardableResult
    public func pause() -> Bool {
        dotLottiePlayer.pause()
    }
    
    @discardableResult
    public func stop() -> Bool {
        dotLottiePlayer.stop()
    }
    
    public func resize(width: Int, height: Int) throws {
        try assertValidRenderSize(width: width, height: height)

        self.WIDTH = UInt32(width)
        self.HEIGHT = UInt32(height)

        try allocateRenderBuffer()
        hasResized = true
    }

    private func assertValidRenderSize(width: Int, height: Int) throws {
        guard width > 0, height > 0 else {
            throw PlayerErrors.invalidRenderSize
        }
    }
    
    public func isStateMachineRunning() -> Bool {
        dotLottiePlayer.isStateMachineRunning
    }

    public func stateMachineLoad(id: String) -> Bool {
        dotLottiePlayer.stateMachineLoad(stateMachineId: id)
    }
    
    public func stateMachineLoadData(_ data: String) -> Bool {
        dotLottiePlayer.stateMachineLoadData(stateMachine: data)
    }
    
    public func stateMachineStart(openUrlPolicy: OpenUrlPolicy = OpenUrlPolicy()) -> Bool {
        return dotLottiePlayer.stateMachineStart(openUrlPolicy: openUrlPolicy)
    }
    
    public func stateMachineStop() -> Bool {
        return dotLottiePlayer.stateMachineStop()
    }
    
    public func stateMachinePostEvent(event: Event) {
        dotLottiePlayer.stateMachinePostEvent(event: event)
    }
    
    public func stateMachineFire(event: String) {
        dotLottiePlayer.stateMachineFireEvent(event: event)
    }
    
    public func stateMachineSubscribe(observer: StateMachineObserver) -> Bool {
        dotLottiePlayer.stateMachineSubscribe(observer: observer)
    }
    
    public func stateMachineUnSubscribe(oberserver: StateMachineObserver) -> Bool {
        dotLottiePlayer.stateMachineUnsubscribe(observer: oberserver)
    }
    
    public func stateMachineInternalSubscribe(observer: StateMachineInternalObserver) -> Bool {
        dotLottiePlayer.stateMachineInternalSubscribe(observer: observer)
    }
    
    public func stateMachineInternalUnsubscribe(observer: StateMachineInternalObserver) -> Bool {
        dotLottiePlayer.stateMachineInternalUnsubscribe(observer: observer)
    }
    
    public func stateMachineFrameworkSetup() -> UInt16 {
        dotLottiePlayer.stateMachineFrameworkSetup()
    }

    public func stateMachineCurrentState() -> String {
        dotLottiePlayer.stateMachineCurrentState()
    }

    public func stateMachineGetInputs() -> [String: String] {
        dotLottiePlayer.stateMachineGetInputs()
    }
    
    public func duration() -> Float32 {
        return dotLottiePlayer.duration()
    }
    
    @discardableResult
    public func setSlots(_ slots: String) -> Bool {
        dotLottiePlayer.setSlotsStr(slots: slots);
    }

    @discardableResult
    public func clearSlots() -> Bool {
        dotLottiePlayer.clearSlots()
    }

    @discardableResult
    public func clearSlot(slotId: String) -> Bool {
        dotLottiePlayer.clearSlot(slotId: slotId)
    }

    @discardableResult
    public func setColorSlot(slotId: String, r: Float, g: Float, b: Float) -> Bool {
        dotLottiePlayer.setColorSlot(slotId: slotId, r: r, g: g, b: b)
    }

    @discardableResult
    public func setScalarSlot(slotId: String, value: Float) -> Bool {
        dotLottiePlayer.setScalarSlot(slotId: slotId, value: value)
    }

    @discardableResult
    public func setTextSlot(slotId: String, text: String) -> Bool {
        dotLottiePlayer.setTextSlot(slotId: slotId, text: text)
    }

    @discardableResult
    public func setVectorSlot(slotId: String, x: Float, y: Float) -> Bool {
        dotLottiePlayer.setVectorSlot(slotId: slotId, x: x, y: y)
    }

    @discardableResult
    public func setPositionSlot(slotId: String, x: Float, y: Float) -> Bool {
        dotLottiePlayer.setPositionSlot(slotId: slotId, x: x, y: y)
    }

    @discardableResult
    public func setImageSlotPath(slotId: String, path: String) -> Bool {
        dotLottiePlayer.setImageSlotPath(slotId: slotId, path: path)
    }

    @discardableResult
    public func setImageSlotDataUrl(slotId: String, dataUrl: String) -> Bool {
        dotLottiePlayer.setImageSlotDataUrl(slotId: slotId, dataUrl: dataUrl)
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
    
    public func stateMachineGetNumericInput(key: String) -> Float {
        dotLottiePlayer.stateMachineGetNumericInput(key: key)
    }
    
    public func stateMachineGetStringInput(key: String) -> String {
        dotLottiePlayer.stateMachineGetStringInput(key: key)
    }
    
    public func stateMachineGetBooleanInput(key: String) -> Bool {
        dotLottiePlayer.stateMachineGetBooleanInput(key: key)
    }
    
    public func getStateMachine(_ id: String) -> String {
        dotLottiePlayer.getStateMachine(stateMachineId: id)
    }

    deinit {
        deallocateRenderBuffer()
    }
}
