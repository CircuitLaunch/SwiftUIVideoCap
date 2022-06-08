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
let objectDetector = CoreMLRequest(modelName: "yolov5s")
let faceDetector = FaceDetectionRequest()
let faceLandmarkDetector = FaceLandmarkDetectionRequest()

let sharedContext = CIContext(options: [.useSoftwareRenderer: false])

struct Detection {
    var id: Int
    var frame: CGRect
    var identifiers: [(id: String, conf: Float)] = []
}

struct FaceDetection {
    var id: Int
    var frame: CGRect
    var confidence: Float = 0.0
    var roll: Angle = .zero
    var yaw: Angle = .zero
    var pitch: Angle = .zero
}

struct FaceLandmarks {
    var id: Int
    var faceContour: [CGPoint] = []
    var leftEye: [CGPoint] = []
    var rightEye: [CGPoint] = []
    var leftEyebrow: [CGPoint] = []
    var rightEyebrow: [CGPoint] = []
    var nose: [CGPoint] = []
    var noseCrest: [CGPoint] = []
    var medianLine: [CGPoint] = []
    var outerLips: [CGPoint] = []
    var innerLips: [CGPoint] = []
    var facePaths: [CGPath] = []
    var leftPupil: CGPoint = .zero
    var rightPupil: CGPoint = .zero
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
    @State private var ciImage = CIImage()
    @State private var nsImage = NSImage()
    
    @State private var detections: [Detection] = []
    @State private var faceDetections: [FaceDetection] = []
    @State private var faceObservations: [VNFaceObservation] = []
    @State private var faceLandmarks: [FaceLandmarks] = []
    
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
                                        ciImage = CIImage(cvImageBuffer: buffer)
                                        
                                        // Submit the image to Vision/CoreML for
                                        // object detection
                                        objectDetector.submit(
                                            image: ciImage,
                                            imgWidth: bounds.width,
                                            imgHeight: bounds.height,
                                            modelWidth: 640.0,
                                            modelHeight: 640.0)
                                            
                                        faceDetector.submit(
                                            image: ciImage,
                                            imgWidth: bounds.width,
                                            imgHeight: bounds.height,
                                            modelWidth: bounds.width,
                                            modelHeight: bounds.height)
                                        
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
                                        // Scale detection frames to the bounds of the video frame
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
                                
                            faceDetector
                                .onDetectionResults { results in
                                    // A counter to provide an id for the benefit of SwiftUI's ForEach view
                                    var i: Int = 0
                                    // Clear previous detections
                                    faceDetections = []
                                    // Clear cache of VNFaceObservations
                                    faceObservations = []
                                    // Iterate through the results of type VNFaceObservaton
                                    for result in results where result is VNFaceObservation {
                                        // Ensure a successful cast
                                        guard let faceObservation = result as? VNFaceObservation else {
                                            continue
                                        }
                                        faceObservations.append(faceObservation)
                                        // Scale detection frames to the bounds of the video frame
                                        let box = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(self.bounds.width), Int(self.bounds.height))
                                        // Instantiate a new Detection object with the id and frame
                                        var detection = FaceDetection(id: i, frame: box)
                                        // Store the confidence factor
                                        detection.confidence = faceObservation.confidence
                                        // Store the orientation: roll, yaw, and pitch
                                        if let a = faceObservation.roll as? Double {
                                            detection.roll = Angle(radians: a)
                                        }
                                        if let a = faceObservation.yaw as? Double {
                                            detection.yaw = Angle(radians: a)
                                        }
                                        if let a = faceObservation.pitch as? Double {
                                            detection.pitch = Angle(radians: a)
                                        }
                                        // Append the new detection to the list
                                        faceDetections.append(detection)
                                        // Increment the integer id
                                        i += 1
                                    }
                                    
                                    // If faces were detected
                                    if faceObservations.count > 0 {
                                        // Initiate a facial landmark detection
                                        faceLandmarkDetector.submit(
                                            image: ciImage,
                                            imgWidth: bounds.width,
                                            imgHeight: bounds.height,
                                            modelWidth: bounds.width,
                                            modelHeight: bounds.height)
                                    }
                                }
                                
                            faceLandmarkDetector
                                .onDetectionResults { results in
                                    // A counter to provide an id for the benefit of SwiftUI's ForEach view
                                    var i: Int = 0
                                    // Clear previous detections
                                    faceLandmarks = []
                                    // Iterate through the results of type VNFaceObservation
                                    for observation in results where observation is VNFaceObservation {
                                        // Ensure a successful cast
                                        guard let landmarksObservation = observation as? VNFaceObservation else {
                                            continue
                                        }
                                        // Get a reference to the landmarks structure
                                        if let lo = landmarksObservation.landmarks {
                                            var landmarks = FaceLandmarks(id: i)
                                            var pathPoints: [[CGPoint]] = []
                                            // For each landmark in the observation, extract the points, and flip them on the y-axis
                                            if let points = lo.faceContour {
                                                let imgPoints = points.pointsInImage(imageSize: bounds.size).map { point in
                                                    CGPoint(x: point.x, y: bounds.height - point.y)
                                                }
                                                landmarks.faceContour = imgPoints
                                                pathPoints.append(imgPoints)
                                            }
                                            if let points = lo.leftEye {
                                                let imgPoints = points.pointsInImage(imageSize: bounds.size).map { point in
                                                    CGPoint(x: point.x, y: bounds.height - point.y)
                                                }
                                                landmarks.leftEye = imgPoints
                                                pathPoints.append(imgPoints)
                                            }
                                            if let points = lo.rightEye {
                                                let imgPoints = points.pointsInImage(imageSize: bounds.size).map { point in
                                                    CGPoint(x: point.x, y: bounds.height - point.y)
                                                }
                                                landmarks.rightEye = imgPoints
                                                pathPoints.append(imgPoints)
                                            }
                                            if let points = lo.rightEyebrow {
                                                let imgPoints = points.pointsInImage(imageSize: bounds.size).map { point in
                                                    CGPoint(x: point.x, y: bounds.height - point.y)
                                                }
                                                landmarks.rightEyebrow = imgPoints
                                                pathPoints.append(imgPoints)
                                            }
                                            if let points = lo.leftEyebrow {
                                                let imgPoints = points.pointsInImage(imageSize: bounds.size).map { point in
                                                    CGPoint(x: point.x, y: bounds.height - point.y)
                                                }
                                                landmarks.leftEyebrow = imgPoints
                                                pathPoints.append(imgPoints)
                                            }
                                            if let points = lo.nose {
                                                let imgPoints = points.pointsInImage(imageSize: bounds.size).map { point in
                                                    CGPoint(x: point.x, y: bounds.height - point.y)
                                                }
                                                landmarks.nose = imgPoints
                                                pathPoints.append(imgPoints)
                                            }
                                            if let points = lo.noseCrest {
                                                let imgPoints = points.pointsInImage(imageSize: bounds.size).map { point in
                                                    CGPoint(x: point.x, y: bounds.height - point.y)
                                                }
                                                landmarks.noseCrest = imgPoints
                                                pathPoints.append(imgPoints)
                                            }
                                            if let points = lo.medianLine {
                                                let imgPoints = points.pointsInImage(imageSize: bounds.size).map { point in
                                                    CGPoint(x: point.x, y: bounds.height - point.y)
                                                }
                                                landmarks.medianLine = imgPoints
                                                pathPoints.append(imgPoints)
                                            }
                                            if let points = lo.outerLips {
                                                let imgPoints = points.pointsInImage(imageSize: bounds.size).map { point in
                                                    CGPoint(x: point.x, y: bounds.height - point.y)
                                                }
                                                landmarks.outerLips = imgPoints
                                                pathPoints.append(imgPoints)
                                            }
                                            if let points = lo.innerLips {
                                                let imgPoints = points.pointsInImage(imageSize: bounds.size).map { point in
                                                    CGPoint(x: point.x, y: bounds.height - point.y)
                                                }
                                                landmarks.innerLips = imgPoints
                                                pathPoints.append(imgPoints)
                                            }
                                            if let points = lo.rightPupil {
                                                let imgPoints = points.pointsInImage(imageSize: bounds.size).map { point in
                                                    CGPoint(x: point.x, y: bounds.height - point.y)
                                                }
                                                landmarks.rightPupil = imgPoints[0]
                                            }
                                            if let points = lo.leftPupil {
                                                let imgPoints = points.pointsInImage(imageSize: bounds.size).map { point in
                                                    CGPoint(x: point.x, y: bounds.height - point.y)
                                                }
                                                landmarks.leftPupil = imgPoints[0]
                                            }
                                            // Construct an array of CGPaths to be
                                            // rendered by SwiftUI
                                            for points in pathPoints {
                                                let path = CGMutablePath()
                                                path.move(to: points[0])
                                                for i in 1 ..< points.count {
                                                    path.addLine(to: points[i])
                                                }
                                                path.closeSubpath()
                                                landmarks.facePaths.append(path)
                                            }
                                            faceLandmarks.append(landmarks)
                                        }
                                        i += 1
                                    }
                                }
                                
                            // Start object detection
                            objectDetector
                                .start()
                            
                            // Start face detection
                            faceDetector
                                .start()
                                
                            // Start face landmark detection
                            faceLandmarkDetector
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
                        // Yet another ZStack to contain the frame and a list of
                        // identifiers and confidence factors
                        // Please note that the returned frames are actually flipped on the y,
                        // which makes no difference to their heights, but requires us to take
                        // the complement of the y position with respect to the frame height.
                        ZStack {
                            // Laying out the identifiers and confidences
                            VStack {
                                ForEach(d.identifiers, id: \.id) { id, conf in
                                    HStack {
                                        Text("\(id)").font(.system(size: 24.0))
                                            .foregroundColor(Color.red)
                                        Spacer()
                                        Text(String(format: "%2.0f%%", conf * 100.0)).font(.system(size: 24.0))
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
                                .strokeBorder(Color.red, style: StrokeStyle(lineWidth: 3.0))
                                .frame(width: d.frame.width, height: d.frame.height)
                                .position(x: d.frame.origin.x + d.frame.width * 0.5, y: bounds.height - (d.frame.origin.y + d.frame.height * 0.5))
                        }
                    }
                }
                    .clipped()
                
                // Clipped ZStack to layer detected face frames over the video
                ZStack {
                    // Iterate through the landmarks
                    ForEach(faceLandmarks, id: \.id) { d in
                        ZStack {
                            ForEach(d.facePaths, id: \.self) { p in
                                Path(p)
                                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 3.0))
                            }
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 10.0, height: 10.0)
                                .position(x: d.rightPupil.x, y: d.rightPupil.y)
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 10.0, height: 10.0)
                                .position(x: d.leftPupil.x, y: d.leftPupil.y)
                        }
                    }
                    // Iterate through the face detections
                    ForEach(faceDetections, id: \.id) { d in
                        // Laying out the identifier, confidence, and orientation
                        VStack {
                            HStack {
                                Text("Face")
                                    .font(.system(size: 24.0))
                                    .foregroundColor(Color.red)
                                Spacer()
                                Text(String(format: "%2.0f%%", d.confidence * 100.0)).font(.system(size: 24.0))
                                    .foregroundColor(Color.red)
                            }
                                .padding(5)
                            Spacer()
                            Text(String(format: "R: %.2fº, Y: %.2fº, P: %.2fº", d.roll.degrees, d.yaw.degrees, d.pitch.degrees))
                                .font(.system(size: 18.0))
                                .foregroundColor(Color.white)
                                .padding(5)
                        }
                            .frame(width: d.frame.width, height: d.frame.height)
                            .position(x: d.frame.origin.x + d.frame.width * 0.5, y: bounds.height - (d.frame.origin.y + d.frame.height * 0.5))
                        // The bounding frame
                        Rectangle()
                            .strokeBorder(Color.red, style: StrokeStyle(lineWidth: 3.0))
                            .frame(width: d.frame.width, height: d.frame.height)
                            .position(x: d.frame.origin.x + d.frame.width * 0.5, y: bounds.height - (d.frame.origin.y + d.frame.height * 0.5))
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
