//
//  DeepVision.swift
//  SwiftUIVideoCap
//
//  Created by Edward Janne on 6/1/22.
//

import Foundation
import AVFoundation
import CoreML
import Vision

class DeepVision {
    let modelName: String
    let modelExt: String
    var requests: [VNCoreMLRequest] = []
    
    init(modelName name: String, ext: String = "mlmodelc") {
        // The file name of the deep learning model to load
        modelName = name
        // The file extension of the deep leanring model to load
        // Defaults to "mlmodelc", which is what Xcode will name
        // the binary version of the file.
        modelExt = ext
    }
    
    func start() {
        // Get the resource url of the model, exit if it couldn't
        // be found
        guard let modelURL =
            Bundle.main.url(
                forResource: modelName,
                withExtension: modelExt)
        else {
            print("\(modelName).\(modelExt) not found")
            return }
        
        // Catch exceptions thrown while loading the ML model
        do {
            // Try loading the model
            let model = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            // Instantiate a request object, passing it the model, and a closure
            // which Vision will call when the model produces results.
            let detector = VNCoreMLRequest(model: model) { (request, error) in
                // Do not process the results on the detection thread
                // but pass if off to the main thread
                DispatchQueue.main.async {
                    // Extract the results
                    if let results = request.results {
                        // Call a custom closure, if available to
                        // process the results
                        self._onDetectionResults?(results)
                    }
                }
            }
            // Keep a reference to the request so it doesn't get
            // garbage collected when this function exits
            self.requests = [detector]
        // Report if an exception is thrown while loading the model
        } catch let error as NSError {
            print("Failed to load\(modelName).\(modelExt): \(error)")
        }
    }
    
    // Optional closure to be called when object detection results are available
    private var _onDetectionResults: (([Any])->())? = nil
    // Function to set the closure
    @discardableResult func onDetectionResults(_ c: (([Any])->())?)->DeepVision {
        _onDetectionResults = c
        return self
    }
    
    func submit(image: CIImage, xScale: CGFloat, yScale: CGFloat) {
        // Scale the image
        if let scaledImage = image.scaled(x: xScale, y: yScale) {
            let bounds = CGRect(x: 0.0, y: 0.0, width: image.extent.width, height: image.extent.height)
            // Convert it to a CoreGraphics image and then into a Cocoa NSImage
            if let cgImage = sharedContext.createCGImage(scaledImage, from: bounds) {
                // Create a request handler that will submit the image to the MLModel
                let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage)
                do {
                    // Submit the image
                    try imageRequestHandler.perform(self.requests)
                } catch {
                    print(error)
                }
            }
        }
    }
}
