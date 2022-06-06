//
//  FaceDetector.swift
//  SwiftUIVideoCap
//
//  Created by Edward Janne on 6/5/22.
//

import Foundation
import Vision

class FaceDetector: VisionRequest {
    override func createDetector(_ completion: VNRequestCompletionHandler?)->VNRequest? {
        return VNDetectFaceRectanglesRequest(completionHandler: completion)
    }
}

class FaceLandmarkDetector: VisionRequest{
    var faceDetector: VNDetectFaceLandmarksRequest? = nil
    
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

class HumanDetector: VisionRequest {
    override func createDetector(_ completion: VNRequestCompletionHandler?)->VNRequest? {
        return VNDetectHumanRectanglesRequest(completionHandler: completion)
    }
}

class BodyPoseDetector: VisionRequest {
    override func createDetector(_ completion: VNRequestCompletionHandler?)->VNRequest? {
        return VNDetectHumanBodyPoseRequest(completionHandler: completion)
    }
}

class HandPoseDetector: VisionRequest {
    override func createDetector(_ completion: VNRequestCompletionHandler?)->VNRequest? {
        return VNDetectHumanHandPoseRequest(completionHandler: completion)
    }
}
