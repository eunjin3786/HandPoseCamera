import UIKit

class HandGestureProcessor {
    
    enum State {
        case pinched
        case unknown
    }

    func getHandState(thumbTip: CGPoint, indexTip: CGPoint, middleMcp: CGPoint, ringMcp: CGPoint, littleMcp: CGPoint) -> State {
        let distanceY = abs(indexTip.y - thumbTip.y)
        
        print("distance \(distanceY)")
        print("index \(indexTip)")
        print("middle \(middleMcp)")
        print("ring \(ringMcp)")
        print("little \(littleMcp)")
        
        if distanceY < 40 {
            return .pinched
        } else if distanceY < 200 {
            if indexTip.y > middleMcp.y && indexTip.y > ringMcp.y && indexTip.y > littleMcp.y {
                return .pinched
            } else {
                return .unknown
            }
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
