import Foundation
import UIKit

enum GestureManagerStatus {
    case unknown
    case fail
    case success
}

protocol GestureManagerDelegate: AnyObject {
    func gestureManagerDidRecognizeMove(_ gestureManager: GestureManager, at location: CGPoint)
    func gestureManagerDidRecognizeDown(_ gestureManager: GestureManager, at location: CGPoint)
    func gestureManagerDidRecognizeUp(_ gestureManager: GestureManager, at location: CGPoint)
}

class GestureManager : UIGestureRecognizer {
    private var lastTouchTime : CFTimeInterval = CACurrentMediaTime()
    private(set) var status = GestureManagerStatus.unknown
    private(set) var doubleTapGestureThreshold : CFTimeInterval = 0.25
    weak var gestureManagerDelegate: GestureManagerDelegate?

   /// Customize double-tap gesture recognizer timing
    // if time between continious taps is smaller than threshold value , then gesture succeed
    func setThreshold(threshold:CFTimeInterval) {
        self.doubleTapGestureThreshold = threshold
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        self.state = .began
        self.status = .unknown
        
        // Check if there's a touch
        if let touch = touches.first {
            // Get the location of the touch in the view's coordinate system
            let location = touch.location(in: self.view)
            gestureManagerDelegate?.gestureManagerDidRecognizeDown(self, at: location)
        }
    }

    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        self.state = .changed

        // Check if there's a touch
        if let touch = touches.first {
            // Get the location of the touch in the view's coordinate system
            let location = touch.location(in: self.view)
            gestureManagerDelegate?.gestureManagerDidRecognizeMove(self, at: location)
            
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        let currentTime = CACurrentMediaTime()
        let diff:CFTimeInterval = currentTime - lastTouchTime
        
        self.status = diff < doubleTapGestureThreshold ? GestureManagerStatus.success : GestureManagerStatus.fail
        self.state = .ended
        
        lastTouchTime = currentTime
        // Check if there's a touch
        if let touch = touches.first {
            // Get the location of the touch in the view's coordinate system
            let location = touch.location(in: self.view)

            gestureManagerDelegate?.gestureManagerDidRecognizeUp(self, at: location)
        }
        
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
    }
}
