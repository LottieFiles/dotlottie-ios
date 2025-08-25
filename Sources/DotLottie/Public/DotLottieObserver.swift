//
//  DotLottieObserver.swift
//
//
//  Created by Sam on 04/03/2024.
//

import Foundation

class DotLottieObserver: Observer {
    var observedPlayer: Player?
    
    init(_ observedPlayer: Player) {
        self.observedPlayer = observedPlayer
    }
    
    deinit {
        self.observedPlayer = nil
    }
    
    func onLoad() {
    }
    
    func onLoop(loopCount: UInt32) {
    }
    
    func onComplete() {
    }
    
    func onFrame(frameNo: Float) {
    }
    
    func onPause() {
    }
    
    func onPlay() {
    }
    
    func onRender(frameNo: Float) {
    }
    
    func onStop() {
    }
    
    func onLoadError() {
    }
}
