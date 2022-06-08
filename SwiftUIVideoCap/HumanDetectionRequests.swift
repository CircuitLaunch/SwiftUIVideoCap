//
//  HumanDetectionRequests.swift
//  SwiftUIVideoCap
//
//  Created by Edward Janne on 6/5/22.
//

import Foundation
import Vision

class FaceDetectionRequest: VisionRequest {
    override func createDetector(_ completion: VNRequestCompletionHandler?)->VNRequest? {
        return VNDetectFaceRectanglesRequest(completionHandler: completion)
    }
}

class FaceLandmarkDetectionRequest: VisionRequest{
    var faceDetector: VNDetectFaceLandmarksRequest? = nil
    
    // Pass an array of cached face observations to the request object
    var faceObservations: [VNFaceObservation] {
        set {
            if let detector = self.faceDetector {
                detector.inputFaceObservations = newValue
            }
        }
        get {
            if let detector = self.faceDetector, let observations = detector.inputFaceObservations {
                return observations
            }
            return []
        }
    }
    
    override func createDetector(_ completion: VNRequestCompletionHandler?)->VNRequest? {
        self.faceDetector = VNDetectFaceLandmarksRequest(completionHandler: completion)
        return self.faceDetector
    }
}

class HumanDetectionRequest: VisionRequest {
    override func createDetector(_ completion: VNRequestCompletionHandler?)->VNRequest? {
        return VNDetectHumanRectanglesRequest(completionHandler: completion)
    }
}

class BodyPoseDetectionRequest: VisionRequest {
    override func createDetector(_ completion: VNRequestCompletionHandler?)->VNRequest? {
        return VNDetectHumanBodyPoseRequest(completionHandler: completion)
    }
}

class HandPoseDetectionRequest: VisionRequest {
    override func createDetector(_ completion: VNRequestCompletionHandler?)->VNRequest? {
        return VNDetectHumanHandPoseRequest(completionHandler: completion)
    }
}
