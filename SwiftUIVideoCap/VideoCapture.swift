//
//  VideoCapture.swift
//  SwiftUIVideoCap
//
//  Created by Edward Janne on 5/30/22.
//

import Foundation
import AVFoundation

class VideoCapture : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let sessionOutput = AVCaptureVideoDataOutput()
    private let captureQueue = DispatchQueue(label: "VideoDataOutput")
    
    // Start a capture session using the camera with the specified camera id
    func start(using cameraId: String) {
        // If there is an active capture session
        if captureSession.isRunning {
            // Stop it
            captureSession.stopRunning()
            // Disconnect the output
            captureSession.removeOutput(sessionOutput)
            // Disconnect any inputs
            let inputs = captureSession.inputs
            for oldInput in inputs {
                captureSession.removeInput(oldInput)
            }
        }
        
        // Request permission to access the camera if needed
        var allowed = false
        let modal = DispatchGroup()
        modal.enter()
        AVCaptureDevice.requestAccess(for: .video) { flag in
            allowed = flag
            modal.leave()
        }
        modal.wait()
        
        // Abort if permission was denied
        guard allowed else {
            print("Video capture permissions failure")
            return
        }
        
        // Abort if no device with the specified ID exists
        guard let device = AVCaptureDevice(uniqueID: cameraId) else {
            print("Failed to access camera")
            return
        }
        
        // Abort if the device's input is inaccessible
        guard let deviceInput = try? AVCaptureDeviceInput(device: device) else {
            print("Failed to access device input")
            return
        }
        
        // Abort if the device's input cannot be used
        guard captureSession.canAddInput(deviceInput) else {
            print("Failed to add device input to session")
            return
        }
        
        // Abort if the output cannot be attached to the session
        guard captureSession.canAddOutput(sessionOutput) else {
            print("Failed to add device output to session")
            return
        }
        
        // Begin configuring the session
        captureSession.beginConfiguration()

        // Add the input and output
        captureSession.addInput(deviceInput)
        captureSession.addOutput(sessionOutput)
        
        // Configure the output to discard late frames
        sessionOutput.alwaysDiscardsLateVideoFrames = true
        // Configure the output video color format
        sessionOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        // Set this object as the delegate, and specify the
        // dispatch queue on which frames will be delivered
        sessionOutput.setSampleBufferDelegate(self, queue: captureQueue)
        
        // Enable the connection between the camera and the output
        if let connection = sessionOutput.connection(with: .video) {
            connection.isEnabled = true
        }

        // Finalize the configuration
        captureSession.commitConfiguration()
        
        // Start the session
        captureSession.startRunning()
    }
    
    // Terminate the session if it is active
    func stop() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    // Implemention of protocol AVCaptureVideoDataOutputSampleBufferDelegate
    // AVFoundation will call this function when a frame is available
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        // Call closure if available
        self._onCapturedImage?(pixelBuffer)
    }
    
    // Implemention of protocol AVCaptureVideoDataOutputSampleBufferDelegate
    // AVFoundation will call this function when a frame has been dropped
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Dropped frame")
    }
    
    // Closure to be called when a frame is captured
    private var _onCapturedImage: ((CVImageBuffer?)->())? = nil
    
    // Function to enable SwiftUI to attach a closure
    @discardableResult func onCapturedImage(_ c: ((CVImageBuffer?)->())?)->VideoCapture {
        _onCapturedImage = c
        return self
    }
}
