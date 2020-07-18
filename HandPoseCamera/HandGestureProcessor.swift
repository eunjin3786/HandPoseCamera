import UIKit

class HandGestureProcessor {
    
    enum State {
        case thumbUp
        case thumbDown
        case pinched
        case unknown
    }
    
    func getHandState(thumbTip: CGPoint, center: CGPoint) -> State {
        if thumbTip.y < center.y {
            return .thumbUp
        } else {
            return .thumbDown
        }
    }
    
    func getHandState(thumbTip: CGPoint, indexTip: CGPoint) -> State {
        let distance = indexTip.distance(from: thumbTip)
        if distance < 40 {
            return .pinched
        } else {
            return .unknown
        }
    }
}

// MARK: - CGPoint helpers

extension CGPoint {
    
    func distance(from point: CGPoint) -> CGFloat {
        return hypot(point.x - x, point.y - y)
    }
}
