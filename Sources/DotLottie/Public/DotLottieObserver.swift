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
        self.observedPlayer?.setPlayerState(state: .loaded)
    }
    
    func onLoop(loopCount: UInt32) {
    }
    
    func onComplete() {
        self.observedPlayer?.setPlayerState(state: .paused)
    }
    
    // Needed to complete the protocol but not used inside Player for the moment
    func onFrame(frameNo: Float) {
    }
    
    func onPause() {
        self.observedPlayer?.setPlayerState(state: .paused)
    }
    
    func onPlay() {
        self.observedPlayer?.setPlayerState(state: .playing)
    }
    
    // Needed to complete the protocol but not used inside Player for the moment
    func onRender(frameNo: Float) {
    }
    
    func onStop() {
        self.observedPlayer?.setPlayerState(state: .stopped)
    }
    
    func onLoadError() {
        self.observedPlayer?.setPlayerState(state: .error)
    }
}
