import UIKit
import Foundation
import AVFoundation
import Vision
import Photos
import SnapKit
import JinnyAppKit

class CameraViewController: UIViewController {

    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    private let handGestureProcessor = HandGestureProcessor()
    
    private weak var timerLabel: UILabel?
    
    private var isTimerRunning = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareCaptureSession()
        prepareCaptureUI()
        
        prepareTimerView()
        prepareBottomControls()
        
        handPoseRequest.maximumHandCount = 1
    }

    private func prepareCaptureSession() {
        let captureSession = AVCaptureSession()
        
        // Select a front facing camera, make an input.
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: .main)
        captureSession.addOutput(videoOutput)

        let photoOutput = AVCapturePhotoOutput()
        captureSession.addOutput(photoOutput)
        
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
    
    private func prepareTimerView() {
        let timerLabel = UILabel()
        timerLabel.textAlignment = .center
        timerLabel.font = UIFont.systemFont(ofSize: 300)
        
        view.addSubview(timerLabel)
        timerLabel.snp.makeConstraints { maker in
            maker.center.equalToSuperview()
        }
        
        self.timerLabel = timerLabel
    }
    
    private func prepareBottomControls() {
        let captureButton = UIButton()
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 100, weight: .bold, scale: .large)
        let symbolImage = UIImage(systemName: "camera.circle", withConfiguration: symbolConfig)
        captureButton.setImage(symbolImage, for: .normal)
        captureButton.tintColor = .systemYellow
        captureButton.addTarget(self, action: #selector(captureButtonDidTap), for: .touchUpInside)
        
        view.addSubview(captureButton)
        captureButton.snp.makeConstraints { maker in
            maker.bottom.equalToSuperview().offset(-40)
            maker.centerX.equalToSuperview()
            maker.width.height.equalTo(100)
        }
    }
    
    @objc
    private func captureButtonDidTap() {
        self.captureImage()
    }
    
    private func captureImage() {
        guard let photoOutput = captureSession?.outputs.first(where: { $0 is AVCapturePhotoOutput }) as? AVCapturePhotoOutput else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func runTimer(seconds: Int, completion: @escaping () -> Void) {
        isTimerRunning = true

        var timeLeft = seconds
        
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { timer in
            self.timerLabel?.text = "\(timeLeft)"
            timeLeft -= 1
            
            if timeLeft < 0 {
                timer.invalidate()
                self.isTimerRunning = false
                self.timerLabel?.text = nil
            
                completion()
            }
        })
        
        RunLoop.current.add(timer, forMode: RunLoop.Mode.common)
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
            
            let middlePoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyMiddleFinger)
            guard let middleMcpPoint = middlePoints[.handLandmarkKeyMiddleMCP] else {
                return
            }
            
            let ringPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyRingFinger)
            guard let ringMcpPoint = ringPoints[.handLandmarkKeyRingMCP] else {
                return
            }
            
            let littlePoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyLittleFinger)
            guard let littleMcpPoint = littlePoints[.handLandmarkKeyLittleMCP] else {
                return
            }

            DispatchQueue.main.async {
                self.processPoints(thumbTipPoint: thumbTipPoint,
                                   indexTipPoint: indexTipPoint,
                                   middleMcpPoint: middleMcpPoint,
                                   ringMcpPoint: ringMcpPoint,
                                   littleMcpPoint: littleMcpPoint)
            }
        } catch {
            print(error)
        }
    }
    
    private func processPoints(thumbTipPoint: VNRecognizedPoint, indexTipPoint: VNRecognizedPoint, middleMcpPoint: VNRecognizedPoint, ringMcpPoint: VNRecognizedPoint, littleMcpPoint: VNRecognizedPoint) {
        
        // Ignore low confidence points.
        guard thumbTipPoint.confidence > 0.3 && indexTipPoint.confidence > 0.3 && middleMcpPoint.confidence > 0.3 && ringMcpPoint.confidence > 0.3 && littleMcpPoint.confidence > 0.3 else {
            return
        }
        
        guard let thumbTipUIKitPoint = videoPreviewLayer?.layerPointConverted(fromCaptureDevicePoint: thumbTipPoint.toAVFoundationPoint) else {
            return
        }
        
        guard let indexTipUIKitPoint = videoPreviewLayer?.layerPointConverted(fromCaptureDevicePoint: indexTipPoint.toAVFoundationPoint) else {
            return
        }
        
        guard let middleMcpUIKitPoint = videoPreviewLayer?.layerPointConverted(fromCaptureDevicePoint: middleMcpPoint.toAVFoundationPoint) else {
            return
        }
        
        guard let ringMcpUIKitPoint = videoPreviewLayer?.layerPointConverted(fromCaptureDevicePoint: ringMcpPoint.toAVFoundationPoint) else {
            return
        }
        
        guard let littleMcpUIKitPoint = videoPreviewLayer?.layerPointConverted(fromCaptureDevicePoint: littleMcpPoint.toAVFoundationPoint) else {
            return
        }

        let state = handGestureProcessor.getHandState(thumbTip: thumbTipUIKitPoint, indexTip: indexTipUIKitPoint, middleMcp: middleMcpUIKitPoint, ringMcp: ringMcpUIKitPoint, littleMcp: littleMcpUIKitPoint)
        
        switch state {
        case .pinched:
            if isTimerRunning == false {
                runTimer(seconds: 3, completion: {
                    self.captureImage()
                })
            }
        case .unknown:
            break
        }
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard let image = UIImage(data: imageData) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
