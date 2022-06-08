//
//  CoreMLRequest.swift
//  SwiftUIVideoCap
//
//  Created by Edward Janne on 6/1/22.
//

import Foundation
import AVFoundation
import CoreML
import Vision

class CoreMLRequest: VisionRequest {
    let modelName: String
    let modelExt: String
    
    init(modelName name: String, ext: String = "mlmodelc", processingQueue queue: DispatchQueue = DispatchQueue.main) {
        // The file name of the deep learning model to load
        modelName = name
        // The file extension of the deep leanring model to load
        // Defaults to "mlmodelc", which is what Xcode will name
        // the binary version of the file.
        modelExt = ext
        // Pass processing thread to super
        super.init(withProcessingQueue: queue)
    }
    
    override func createDetector(_ completion: VNRequestCompletionHandler?)->VNRequest? {
        // Get the resource url of the model, exit if it couldn't
        // be found
        guard let modelURL =
            Bundle.main.url(
                forResource: modelName,
                withExtension: modelExt)
        else {
            print("\(modelName).\(modelExt) not found")
            return nil }
        
        do {
            // Try loading the model
            let model = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            // Return a new request passing it the given completion closure
            return VNCoreMLRequest(model: model, completionHandler: completion)
        } catch let error as NSError {
            print("Failed to load\(modelName).\(modelExt): \(error)")
        }
        return nil
    }
}
