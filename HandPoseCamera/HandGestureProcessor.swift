import UIKit

class HandGestureProcessor {
    enum State {
        case thumbUp
        case thumbDown
    }
    
    func getHandState(thumbTip: CGPoint, center: CGPoint) -> State {
        if thumbTip.y < center.y {
            return .thumbUp
        } else {
            return .thumbDown
        }
    }
}
