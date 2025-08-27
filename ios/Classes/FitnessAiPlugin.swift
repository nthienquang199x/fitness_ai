import Flutter
import UIKit
import AVFoundation
import MediaPipeTasksVision

public class FitnessAiPlugin: NSObject, FlutterPlugin, FlutterTexture {
  private var captureSession: AVCaptureSession?
  private var videoDevice: AVCaptureDevice?
  private var videoDeviceInput: AVCaptureDeviceInput?
  private var videoDataOutput: AVCaptureVideoDataOutput?
  private var textureId: Int64?
  private var textureRegistry: FlutterTextureRegistry?
  private var eventSink: FlutterEventSink?
  private var eventChannel: FlutterEventChannel?
  
  // Texture management
  private var latestPixelBuffer: CVPixelBuffer?
  private let pixelBufferLock = NSLock()
  
  private let exerciseAnalyzer = ExerciseAnalyzer()
  private var isFrontCamera: Bool = false
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "fitness_ai", binaryMessenger: registrar.messenger())
    let instance = FitnessAiPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    // Set up event channel for landmarks
    let eventChannel = FlutterEventChannel(name: "fitness_ai/landmarks", binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)
    
    // Store texture registry reference
    instance.textureRegistry = registrar.textures()
    
    // Add orientation change observer
    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(instance.orientationChanged),
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startAnalyzeExercise":
      startAnalyzeExercise(call: call, result: result)
    case "stopAnalyzeExercise":
      stopAnalyzeExercise(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func startAnalyzeExercise(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Check camera permission first
    AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
      DispatchQueue.main.async {
        if granted {
          self?.setupCamera(call: call, result: result)
        } else {
          result(FlutterError(code: "PERMISSION_DENIED", 
                             message: "Camera permission denied", 
                             details: nil))
        }
      }
    }
  }
  
  private func setupCamera(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Parse arguments
    let args = call.arguments as? [String: Any]
    let exercise = args?["exercise"] as? String ?? ExerciseAnalyzer.EXERCISE_SQUAT
    let difficulty = args?["difficulty"] as? String ?? ExerciseAnalyzer.DIFFICULTY_MEDIUM
    let thresholdsJson = args?["thresholds"] as? String
    let modelPath = args?["modelAssetPath"] as? String ?? ""
    isFrontCamera = args?["isFrontCamera"] as? Bool ?? false
    
    // Configure ExerciseAnalyzer
    exerciseAnalyzer.setExercise(exercise)
    exerciseAnalyzer.setDifficulty(difficulty)
    if let thresholdsJson = thresholdsJson, !thresholdsJson.isEmpty {
      exerciseAnalyzer.loadThresholds(from: thresholdsJson)
    }
    
    // Configure FitnessAI
    FitnessAI.shared.initialize(path: modelPath)
    FitnessAI.shared.setResultCallback { [weak self] poseResult, width, height in
      self?.handlePoseResult(poseResult: poseResult, width: width, height: height)
    }
    
    // Create capture session
    captureSession = AVCaptureSession()
    guard let captureSession = captureSession else {
      result(FlutterError(code: "CAMERA_ERROR", 
                         message: "Failed to create capture session", 
                         details: nil))
      return
    }
    
    // Configure session
    captureSession.beginConfiguration()
    captureSession.sessionPreset = .high
    
    // Set session to portrait orientation
    if #available(iOS 13.0, *) {
      captureSession.connections.forEach { connection in
        if connection.isVideoOrientationSupported {
          connection.videoOrientation = .portrait
        }
      }
    }
    
    // Get camera device
    let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
    guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                   for: .video, 
                                                   position: position) else {
      result(FlutterError(code: "CAMERA_ERROR", 
                         message: "Failed to get camera device", 
                         details: nil))
      return
    }
    
    self.videoDevice = videoDevice
    
    // Configure camera settings for optimal quality
    do {
      try videoDevice.lockForConfiguration()
      
      // Enable continuous auto focus for better quality
      if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
        videoDevice.focusMode = .continuousAutoFocus
      } else if videoDevice.isFocusModeSupported(.autoFocus) {
        videoDevice.focusMode = .autoFocus
      }
      
      // Enable continuous auto exposure
      if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
        videoDevice.exposureMode = .continuousAutoExposure
      }
      
      // Set white balance to continuous auto
      if videoDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
        videoDevice.whiteBalanceMode = .continuousAutoWhiteBalance
      }
      
      // Reset zoom to 1.0 (no zoom) and ensure no digital zoom
      videoDevice.videoZoomFactor = 1.0
      
      // Set minimum zoom factor to prevent any unwanted zoom
      if videoDevice.minAvailableVideoZoomFactor > 1.0 {
        videoDevice.videoZoomFactor = videoDevice.minAvailableVideoZoomFactor
      }
      
      videoDevice.unlockForConfiguration()
    } catch {
      result(FlutterError(code: "CAMERA_ERROR", 
                         message: "Failed to configure camera settings", 
                         details: error.localizedDescription))
      return
    }
    
    // Create device input
    do {
      videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
      guard let videoDeviceInput = videoDeviceInput else {
        result(FlutterError(code: "CAMERA_ERROR", 
                           message: "Failed to create device input", 
                           details: nil))
        return
      }
      
      if captureSession.canAddInput(videoDeviceInput) {
        captureSession.addInput(videoDeviceInput)
      }
    } catch {
      result(FlutterError(code: "CAMERA_ERROR", 
                         message: "Failed to create camera input", 
                         details: error.localizedDescription))
      return
    }
    
    // Create video data output for processing frames
    videoDataOutput = AVCaptureVideoDataOutput()
    videoDataOutput?.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))
    videoDataOutput?.alwaysDiscardsLateVideoFrames = false
    
    // Configure video settings for better quality
    videoDataOutput?.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    
    if let videoDataOutput = videoDataOutput, captureSession.canAddOutput(videoDataOutput) {
      captureSession.addOutput(videoDataOutput)
      
      // Configure video orientation to fix rotation issues
      if let connection = videoDataOutput.connection(with: .video) {
        if connection.isVideoOrientationSupported {
          // Force portrait orientation to prevent landscape rotation
          connection.videoOrientation = .portrait
        }
        if connection.isVideoMirroringSupported {
          // Mirror front camera
          connection.isVideoMirrored = isFrontCamera
        }
      }
    }
    
    captureSession.commitConfiguration()
    
    // Create texture entry for Flutter
    textureId = textureRegistry?.register(self)
    
    // Start session
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.captureSession?.startRunning()
      
      // Configure camera quality after session starts
      DispatchQueue.main.async {
        self?.configureCameraForQuality()
      }
    }
    
    result(textureId)
  }
  
  private func handlePoseResult(poseResult: PoseLandmarkerResult?, width: Int, height: Int) {

    guard let poseResult = poseResult,
          !poseResult.landmarks.isEmpty else {
      return
    }
    
    let firstPose = poseResult.landmarks[0]
    var points: [CGPoint] = []
    
    for landmark in firstPose {
      let x = landmark.x * Float(width)
      let y = landmark.y * Float(height)
      points.append(CGPoint(x: CGFloat(x), y: CGFloat(y)))
    }
    
    let feedback = exerciseAnalyzer.analyzePose(points)
    
    let overlayPoints = firstPose.map { landmark -> [String: Double] in
      let nx = landmark.x
      let ny = landmark.y
      let px = Double(nx * Float(width))
      let py = Double(ny * Float(height))
      return ["x": px, "y": py]
    }
    
    let payload: [String: Any] = [
      "width": width,
      "height": height,
      "landmarks": overlayPoints,
      "message": feedback.message,
      "repCount": feedback.repCount,
      "correctReps": feedback.correctReps,
      "isCorrect": feedback.isCorrect
    ]
    
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(payload)
    }
  }
  
  private func stopAnalyzeExercise(result: @escaping FlutterResult) {
    // Stop camera capture and cleanup
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.captureSession?.stopRunning()
    }
    
    if let textureId = textureId {
      textureRegistry?.unregisterTexture(textureId)
    }
    
    captureSession = nil
    videoDevice = nil
    videoDeviceInput = nil
    videoDataOutput = nil
    textureId = nil
    
    // Clear texture buffer
    pixelBufferLock.lock()
    latestPixelBuffer = nil
    pixelBufferLock.unlock()
    
    result(nil)
  }
  
  @objc private func orientationChanged() {
    // Force portrait orientation for camera
    if let connection = videoDataOutput?.connection(with: .video),
       connection.isVideoOrientationSupported {
      DispatchQueue.main.async {
        connection.videoOrientation = .portrait
      }
    }
  }
  
  private func configureCameraForQuality() {
    guard let videoDevice = videoDevice else { return }
    
    do {
      try videoDevice.lockForConfiguration()
      
      // Ensure zoom is at 1.0 (no zoom)
      if videoDevice.videoZoomFactor != 1.0 {
        videoDevice.videoZoomFactor = 1.0
      }
      
      // Set focus to center of frame for better quality
      if videoDevice.isFocusPointOfInterestSupported {
        videoDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
      }
      
      // Set exposure point to center
      if videoDevice.isExposurePointOfInterestSupported {
        videoDevice.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
      }
      
      videoDevice.unlockForConfiguration()
    } catch {
      print("Failed to configure camera quality: \(error)")
    }
  }
  
  deinit {
    // Remove orientation observer
    NotificationCenter.default.removeObserver(self)
  }
}

// MARK: - FlutterTexture
extension FitnessAiPlugin {
  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    pixelBufferLock.lock()
    defer { pixelBufferLock.unlock() }
    
    guard let pixelBuffer = latestPixelBuffer else {
      return nil
    }
    
    // Return the pixel buffer with proper memory management
    return Unmanaged.passRetained(pixelBuffer)
  }
}

// MARK: - FlutterStreamHandler
extension FitnessAiPlugin: FlutterStreamHandler {
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }
  
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension FitnessAiPlugin: AVCaptureVideoDataOutputSampleBufferDelegate {
  public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    
    // Update the latest pixel buffer for texture rendering
    pixelBufferLock.lock()
    latestPixelBuffer = imageBuffer
    pixelBufferLock.unlock()
    
    // Notify Flutter that the texture has been updated
    DispatchQueue.main.async { [weak self] in
      self?.textureRegistry?.textureFrameAvailable(self?.textureId ?? 0)
    }
    
    // Convert CVPixelBuffer to UIImage for processing with proper orientation
    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
    let context = CIContext(options: [.useSoftwareRenderer: false])
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
    
    // Create UIImage with proper orientation to prevent rotation issues
    let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    
    // Process frame through FitnessAI
    FitnessAI.shared.detect(image: image, isFrontCamera: isFrontCamera)
  }
}
