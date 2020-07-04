import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController {

    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    private let handGestureProcessor = HandGestureProcessor()
    
    private weak var emojiView: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareCaptureSession()
        prepareCaptureUI()
        prepareEmojiView()
        
        // The default value for this property is 2.
        handPoseRequest.maximumHandCount = 1
    }
    
    private func prepareCaptureSession() {
        let captureSession = AVCaptureSession()
        
        // Select a front facing camera, make an input.
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: .main)
        captureSession.addOutput(output)

        self.captureSession = captureSession
        self.captureSession?.startRunning()
    }
    
    private func prepareCaptureUI() {
        guard let session = captureSession else { return }
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = view.layer.bounds
        view.layer.addSublayer(videoPreviewLayer)
        
        self.videoPreviewLayer = videoPreviewLayer
    }
    
    private func prepareEmojiView() {
        let emojiView = UILabel()
        emojiView.frame = self.view.bounds
        emojiView.textAlignment = .center
        emojiView.font = UIFont.systemFont(ofSize: 300)
        view.addSubview(emojiView)
        
        self.emojiView = emojiView
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([handPoseRequest])
            // Continue only when a hand was detected in the frame.
            // Since we set the maximumHandCount property of the request to 1, there will be at most one observation.
            guard let observation = handPoseRequest.results?.first as? VNRecognizedPointsObservation else {
                return
            }
            // type: [VNRecognizedPointKey : VNRecognizedPoint]
            let thumbPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyThumb)
            
            // type: VNRecognizedPoint?
            guard let thumbTipPoint = thumbPoints[.handLandmarkKeyThumbTIP] else {
                emojiView?.text = "😰"
                return
            }
            
            // Ignore low confidence points.
            guard thumbTipPoint.confidence > 0.3 else {
                emojiView?.text = "😭"
                return
            }
            
            DispatchQueue.main.async {
                self.processPoints(thumbTipPoint: thumbTipPoint)
            }
        } catch {
            print("에러 \(error)")
        }
    }
    
    private func processPoints(thumbTipPoint: VNRecognizedPoint) {
        // Convert points from Vision coordinates to AVFoundation coordinates.
        let thumbTipCGPoint = CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y)
        
        // Convert points from AVFoundation coordinates to UIKit coordinates.
        guard let thumbTipConvertedPoint = videoPreviewLayer?.layerPointConverted(fromCaptureDevicePoint: thumbTipCGPoint) else {
            emojiView?.text = "😱"
            return
        }

        let state = handGestureProcessor.getHandState(thumbTip: thumbTipConvertedPoint, center: self.view.center)
        
        switch state {
        case .thumbUp:
            emojiView?.text = "👍"
        case .thumbDown:
            emojiView?.text = "👎"
        }

        print("1. Vision Coordinates: \(thumbTipPoint)")
        print("2. AVFoundation coordinates: \(thumbTipCGPoint)")
        print("3. UIKit coordinates: \(thumbTipConvertedPoint)")
        print(state)
    }
}
