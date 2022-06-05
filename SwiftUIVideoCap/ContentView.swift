//
//  ContentView.swift
//  SwiftUIVideoCap
//
//  Created by Edward Janne on 5/30/22.
//

import SwiftUI
import AVFoundation
import Vision

let videoCapture = VideoCapture()
let objectDetector = DeepVision(modelName: "yolov5s")

let sharedContext = CIContext(options: [.useSoftwareRenderer: false])

struct Detection {
    var id: Int
    var frame: CGRect
    var identifiers: [(id: String, conf: Float)] = []
}

struct ContentView: View {
    // An array to store the names of available cameras
    @State private var cameraNames = [String]()
    // A map to associate names with camera ids
    @State private var cameraIds = [String:String]()
    // The name of the currently selected camera
    @State private var selectedCamera = "FaceTime HD Camera"
    
    // The bounds of the captured frames
    @State var bounds = CGRect(x:0.0, y:0.0, width:100.0, height:100.0)
    // The scaling factor for display
    @State var scale: Double = 1.0
    
    // The currently captured frame as an NSImage
    @State private var nsImage = NSImage()
    
    @State private var detections: [Detection] = []
    
    var body: some View {
        // Vertical stack containing a Picker, and an Image
        VStack(spacing: 0.0) {
            // Create a Picker named "Cameras" and bind
            // selectedCamera to its selected option
            Picker("Cameras", selection: $selectedCamera) {
                // Populate the picker with the camera names
                ForEach(cameraNames, id: \.self) { name in
                    // The displayed text is the name of each camera
                    // The tag is the value to return in selectedCamera
                    // when the user picks an option; in this case is
                    // also the camera name
                    Text(name).tag(name)
                }
            }
                .pickerStyle(.segmented)
                .padding(10)
            ZStack {
                // Image to display the captured frames
                Image(nsImage: nsImage)
                    .onAppear {
                            // Get the list of attached cameras
                            let discoveredCameraList =
                                AVCaptureDevice.DiscoverySession(
                                    deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
                                    mediaType: .video,
                                    position: .unspecified
                                ).devices
                            // Populate the names array and the name:id map
                            for discovered in discoveredCameraList {
                                cameraNames.append(discovered.localizedName)
                                cameraIds[discovered.localizedName] = discovered.uniqueID
                            }
                            
                            // Attach a closure to the videoCapture object to handle incoming frames
                            videoCapture
                                .onCapturedImage { buffer in
                                    if let buffer = buffer {
                                        // Get the dimensions of the image
                                        let width = CVPixelBufferGetWidth(buffer)
                                        let height = CVPixelBufferGetHeight(buffer)
                                        var bounds = CGRect(x: 0, y: 0, width: width, height: height)
                                        // Create a CoreImage image class with the buffer
                                        var ciImage = CIImage(cvImageBuffer: buffer)
                                        
                                        // Submit the image to Vision/CoreML for
                                        // object detection
                                        objectDetector.submit(
                                            image: ciImage,
                                            imgWidth: bounds.width,
                                            imgHeight: bounds.height,
                                            modelWidth: 640.0,
                                            modelHeight: 640.0)
                                        
                                        // Scale the image
                                        if let scaledImage = ciImage.scaled(by: scale) {
                                            ciImage = scaledImage
                                            bounds.size = CGSize(width: Int(Double(width) * scale), height: Int(Double(height) * scale))
                                        }

                                        // Convert it to a CoreGraphics image and then into a Cocoa NSImage
                                        if let cgImage = sharedContext.createCGImage(ciImage, from: bounds) {
                                            nsImage = NSImage(cgImage: cgImage, size: bounds.size)
                                        }
                                        // Update the image dimensions source of truth
                                        self.bounds = bounds
                                    }
                                }
                                
                            // Attach a closure to the objectDetector object to handle detection results
                            objectDetector
                                .onDetectionResults { results in
                                    // A counter to provide an id for the benefit of SwiftUI's ForEach view
                                    var i: Int = 0
                                    // Clear previous detections
                                    detections = []
                                    // Iterate through the results of type VNRecognizedObjectObservation
                                    for result in results where result is VNRecognizedObjectObservation {
                                        // Ensure a successful cast
                                        guard let objectObservation = result as? VNRecognizedObjectObservation else {
                                            continue
                                        }
                                        // Renormalize detection frames to the bounds of the video frame
                                        let box = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(self.bounds.width), Int(self.bounds.height))
                                        // Instantiate a new Detection object with the id and frame
                                        var detection = Detection(id: i, frame: box)
                                        // Iterate through the result identifiers
                                        for label in objectObservation.labels {
                                            // Filter out spurious detections
                                            if label.confidence > 0.9 {
                                                // Append the identifier/confidence factor pair as a tuple
                                                detection.identifiers.append((label.identifier, label.confidence))
                                            }
                                        }
                                        // Add the new detection to the list
                                        detections.append(detection)
                                        // Increment the integer id
                                        i += 1
                                    }
                                }
                                
                            // Start object detection
                            objectDetector
                                .start()
                                
                            // Start capturing
                            if let selectedId = cameraIds[selectedCamera] {
                                videoCapture.start(using: selectedId)
                            }
                        }
                    .onChange(of: selectedCamera) { newValue in
                            // Restart when the user selects abother camera
                            if let selectedId = cameraIds[selectedCamera] {
                                videoCapture.start(using: selectedId)
                            }
                        }
                        
                // Clipped ZStack to layer detected object frames over the video
                ZStack {
                    // Iterate through the detections
                    ForEach(detections, id: \.id) { d in
                        // Yet another ZStack to containe the frame and a list of
                        // identifiers and confidence factors
                        // Please note that the returned frames are actually flipped on the y,
                        // which makes no difference to their heights, but requires us to take
                        // the complement of the y position with respect to the frame height.
                        ZStack {
                            // Laying out the identifiers and confidences
                            VStack {
                                ForEach(d.identifiers, id: \.id) { id, conf in
                                    HStack {
                                        Text("\(id)").font(.system(size: 12.0))
                                            .foregroundColor(Color.red)
                                        Spacer()
                                        Text(String(format: "%2.0f%%", conf * 100.0)).font(.system(size: 12.0))
                                            .foregroundColor(Color.red)
                                    }
                                        .padding(5)
                                }
                                Spacer()
                            }
                                .frame(width: d.frame.width, height: d.frame.height)
                                .position(x: d.frame.origin.x + d.frame.width * 0.5, y: bounds.height - (d.frame.origin.y + d.frame.height * 0.5))
                            // The bounding frame
                            Rectangle()
                                .strokeBorder(Color.red, style: StrokeStyle(lineWidth: 1.0))
                                .frame(width: d.frame.width, height: d.frame.height)
                                .position(x: d.frame.origin.x + d.frame.width * 0.5, y: bounds.height - (d.frame.origin.y + d.frame.height * 0.5))
                        }
                    }
                }
                    .clipped()
            }
        }
            // Shrink view to contents
            .frame(width: bounds.width)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension CIImage {
    // Extension to make it easy to scale a CIImage
    func scaled(by scale: Double)->CIImage? {
        if let filter = CIFilter(name: "CILanczosScaleTransform") {
            filter.setValue(self, forKey: "inputImage")
            filter.setValue(scale, forKey: "inputScale")
            filter.setValue(1.0, forKey: "inputAspectRatio")
            return filter.value(forKey: "outputImage") as? CIImage
        }
        return nil
    }
    
    // Non-uniform scaling
    func scaled(x: CGFloat, y: CGFloat)->CIImage? {
        if let filter = CIFilter(name: "CIAffineTransform") {
            let xform = NSAffineTransform(transform: AffineTransform(scaleByX: x, byY: y))
            filter.setValue(self, forKey: "inputImage")
            filter.setValue(xform, forKey: "inputTransform")
            return filter.value(forKey: "outputImage") as? CIImage
        }
        return nil
    }
}
