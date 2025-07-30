import Foundation

#if os(iOS)
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
    func gestureManagerDidRecognizeTap(_ gestureManager: GestureManager, at location: CGPoint)
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
    
    private var initialTouchLocation: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        self.state = .began
        self.status = .unknown
        
        // Check if there's a touch
        if let touch = touches.first {
            // Get the location of the touch in the view's coordinate system
            let location = touch.location(in: self.view)
            initialTouchLocation = location
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
        let diff: CFTimeInterval = currentTime - lastTouchTime
        
        if let touch = touches.first {
            let location = touch.location(in: self.view)
            
            // Check if this could be part of a double tap
            if diff < doubleTapGestureThreshold {
                self.status = .success
            } else {
                self.status = .fail
                
                // This is a single tap if it's not part of a double tap
                if let initialLocation = initialTouchLocation {
                    let moveDistance = hypot(location.x - initialLocation.x, location.y - initialLocation.y)
                    let maxTapDistance: CGFloat = 20
                    
                    if moveDistance <= maxTapDistance && diff >= doubleTapGestureThreshold {
                        gestureManagerDelegate?.gestureManagerDidRecognizeTap(self, at: location)
                    }
                }

                initialTouchLocation = nil
            }
            
            gestureManagerDelegate?.gestureManagerDidRecognizeUp(self, at: location)
        }
        
        self.state = .ended
        lastTouchTime = currentTime
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
    }
}

#endif

#if os(macOS)
enum GestureManagerStatus {
    case unknown
    case fail
    case success
}

protocol GestureManagerDelegate: AnyObject {
    func gestureManagerDidRecognizeMove(_ gestureManager: GestureManager, at location: CGPoint)
    func gestureManagerDidRecognizeDown(_ gestureManager: GestureManager, at location: CGPoint)
    func gestureManagerDidRecognizeUp(_ gestureManager: GestureManager, at location: CGPoint)
    func gestureManagerDidRecognizeTap(_ gestureManager: GestureManager, at location: CGPoint)
    func gestureManagerDidRecognizeHover(_ gestureManager: GestureManager, at location: CGPoint)
    func gestureManagerDidRecognizeExitHover(_ gestureManager: GestureManager, at location: CGPoint)
}

class GestureManager {
    private var lastClickTime: CFTimeInterval = CFAbsoluteTimeGetCurrent()
    private(set) var status = GestureManagerStatus.unknown
    private(set) var doubleClickThreshold: CFTimeInterval = 0.25
    weak var gestureManagerDelegate: GestureManagerDelegate?
    
    private var initialClickLocation: CGPoint?
    private var isDragging = false
    private var isHovering = false
    
    func setThreshold(threshold: CFTimeInterval) {
        self.doubleClickThreshold = threshold
    }
    
    // MARK: - Mouse Event Handling
    
    func handleMouseDown(at location: CGPoint) {
        initialClickLocation = location
        isDragging = false
        status = .unknown
        
        gestureManagerDelegate?.gestureManagerDidRecognizeDown(self, at: location)
    }
    
    func handleMouseDragged(at location: CGPoint) {
        isDragging = true
        gestureManagerDelegate?.gestureManagerDidRecognizeMove(self, at: location)
    }
    
    func handleMouseUp(at location: CGPoint) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let timeDiff = currentTime - lastClickTime
        
        // Determine if this is a tap (click without significant drag)
        if let initialLocation = initialClickLocation, !isDragging {
            let moveDistance = hypot(location.x - initialLocation.x, location.y - initialLocation.y)
            let maxClickDistance: CGFloat = 5.0 // Smaller threshold for mouse clicks
            
            if moveDistance <= maxClickDistance {
                if timeDiff >= doubleClickThreshold {
                    gestureManagerDelegate?.gestureManagerDidRecognizeTap(self, at: location)
                    status = .fail
                } else {
                    status = .success
                }
            }
        }
        
        gestureManagerDelegate?.gestureManagerDidRecognizeUp(self, at: location)
        
        lastClickTime = currentTime
        initialClickLocation = nil
        isDragging = false
    }
    
    func handleMouseMoved(at location: CGPoint) {
        if !isHovering {
            isHovering = true
        }
        
        gestureManagerDelegate?.gestureManagerDidRecognizeMove(self, at: location)
    }
    
    func handleMouseEntered(at location: CGPoint) {
        isHovering = true
        gestureManagerDelegate?.gestureManagerDidRecognizeHover(self, at: location)
    }
    
    func handleMouseExited(at location: CGPoint) {
        isHovering = false
        gestureManagerDelegate?.gestureManagerDidRecognizeExitHover(self, at: location)
    }
}

#endif
