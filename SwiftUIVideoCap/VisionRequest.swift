//
//  VisionRequest.swift
//  SwiftUIVideoCap
//
//  Created by Edward Janne on 6/5/22.
//

import Foundation
import AVFoundation
import Vision

class VisionRequest {
    var processingQueue: DispatchQueue
    var requests: [VNRequest] = []
    
    init(withProcessingQueue queue: DispatchQueue = DispatchQueue.main) {
        processingQueue = queue
    }
    
    // Override in a subclass to create a specific VNRequest class
    func createDetector(_ completion: VNRequestCompletionHandler?)->VNRequest? {
        return nil
    }
    
    func start() {
        // Create a new detector
        if let detector = createDetector({ (request, error) in
            // Do not process the results on the detection thread
            // but pass if off to the processing thread
            self.processingQueue.async {
                // Extract the results
                if let results = request.results {
                    // Call a custom closure, if available to
                    // process the results
                    self._onDetectionResults?(results)
                }
            }
        }) {
            // Keep a reference to the request so it doesn't get
            // garbage collected when this function exits
            self.requests = [detector]
        }
    }
    
    // Optional closure to be called when object detection results are available
    private var _onDetectionResults: (([Any])->())? = nil
    // Function to set the closure
    @discardableResult func onDetectionResults(_ c: (([Any])->())?)->VisionRequest {
        _onDetectionResults = c
        return self
    }
    
    func submit(image: CIImage, imgWidth: CGFloat, imgHeight: CGFloat, modelWidth: CGFloat, modelHeight: CGFloat) {
        if let img = (((imgWidth == modelWidth) && (imgHeight == modelHeight)) ? image : image.scaled(x: modelWidth / imgWidth, y: modelHeight / imgHeight)) {
            let bounds = CGRect(x: 0.0, y: 0.0, width: modelWidth, height: modelHeight)
            // Convert it to a CoreGraphics image and then into a Cocoa NSImage
            if let cgImage = sharedContext.createCGImage(img, from: bounds) {
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
