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
            
            guard let observation = handPoseRequest.results?.first as? VNRecognizedPointsObservation else {
                return
            }
            
            let thumbPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyThumb)
            guard let thumbTipPoint = thumbPoints[.handLandmarkKeyThumbTIP] else {
                return
            }
            
            let indexPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyIndexFinger)
            guard let indexTipPoint = indexPoints[.handLandmarkKeyIndexTIP] else {
                return
            }
            
            // Ignore low confidence points.
            guard thumbTipPoint.confidence > 0.3 || indexTipPoint.confidence > 0.3 else {
                emojiView?.text = "😭"
                return
            }
            
            DispatchQueue.main.async {
                self.processPoints(thumbTipPoint: thumbTipPoint,
                                   indexTipPoint: indexTipPoint)
            }
        } catch {
            print("에러 \(error)")
        }
    }
    
    private func processPoints(thumbTipPoint: VNRecognizedPoint, indexTipPoint: VNRecognizedPoint) {
        
        guard let thumbTipUIKitPoint = videoPreviewLayer?.layerPointConverted(fromCaptureDevicePoint: thumbTipPoint.toAVFoundationPoint) else {
            return
        }
        
        guard let indexTipUIKitPoint = videoPreviewLayer?.layerPointConverted(fromCaptureDevicePoint: indexTipPoint.toAVFoundationPoint) else {
            return
        }
        
        let state = handGestureProcessor.getHandState(thumbTip: thumbTipUIKitPoint, indexTip: indexTipUIKitPoint)
        
        switch state {
        case .thumbUp:
            emojiView?.text = "👍"
        case .thumbDown:
            emojiView?.text = "👎"
        case .pinched:
            emojiView?.text = "👌"
        case .unknown:
            break
        }

        print(state)
    }
}

extension VNRecognizedPoint {
    
    var toAVFoundationPoint: CGPoint {
        return CGPoint(x: self.location.x, y: 1 - self.location.y)
    }
}
