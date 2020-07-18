import Vision

extension VNRecognizedPoint {
    
    var toAVFoundationPoint: CGPoint {
        return CGPoint(x: self.location.x, y: 1 - self.location.y)
    }
}
