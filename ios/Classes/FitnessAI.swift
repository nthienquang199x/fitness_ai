//
//  FitnessAI.swift
//  FitnessAI
//
//  Created by Quang Nguyễn on 8/16/25.
//
import MediaPipeTasksVision
import UIKit
import AVFoundation

protocol IFitnessAI {
    func initialize(path: String)
    func detect(image: UIImage, isFrontCamera: Bool)
    func setResultCallback(callback: @escaping (PoseLandmarkerResult?, Int, Int) -> Void)
}

class FitnessAI : NSObject, IFitnessAI {
    static let shared = FitnessAI()
    private var landmarker: PoseLandmarker?
    private var resultCallback: ((PoseLandmarkerResult?, Int, Int) -> Void)?
    private var lastImageWidth: Int = 1080
    private var lastImageHeight: Int = 1920
    
    private override init() {
        super.init()
    }
    
    func initialize(path: String) {
        let options = PoseLandmarkerOptions()
        options.runningMode = .liveStream
        options.minPoseDetectionConfidence = 0.2
        options.minTrackingConfidence = 0.2
        options.baseOptions.delegate = .GPU
        
        if !path.isEmpty {
            options.baseOptions.modelAssetPath = path
        }
        
        // Set result listener for live stream mode
        options.poseLandmarkerLiveStreamDelegate = self
        
        do {
            landmarker = try PoseLandmarker(options: options)
            print("PoseLandmarker initialized successfully")
        } catch {
            print("Error initializing PoseLandmarker: \(error)")
        }
    }
    
    func setResultCallback(callback: @escaping (PoseLandmarkerResult?, Int, Int) -> Void) {
        resultCallback = callback
    }
    
    func detect(image: UIImage, isFrontCamera: Bool) {
        guard let landmarker = landmarker else {
            print("PoseLandmarker not initialized. Call initialize() first.")
            return
        }
        
        // Store image dimensions
        lastImageWidth = Int(image.size.width)
        lastImageHeight = Int(image.size.height)
        
        let frameTime = Date().timeIntervalSince1970 * 1000
        
        // Convert UIImage to MPImage
        guard let mpImage = try? MPImage(uiImage: image) else {
            print("Failed to convert UIImage to MPImage")
            return
        }
        
        // Detect pose asynchronously
        do {
            try landmarker.detectAsync(image: mpImage, timestampInMilliseconds: Int(frameTime))
        } catch {
            print("Error detecting pose: \(error)")
        }
    }
}

// MARK: - PoseLandmarkerLiveStreamDelegate
extension FitnessAI: PoseLandmarkerLiveStreamDelegate {
    func poseLandmarker(_ poseLandmarker: PoseLandmarker, didFinishDetection result: PoseLandmarkerResult?, timestampInMilliseconds: Int, error: Error?) {
        if let error = error {
            print("MediaPipe error: \(error)")
            return
        }
        
        // Call the callback with the result and stored image dimensions
        resultCallback?(result, lastImageWidth, lastImageHeight)
    }
}
