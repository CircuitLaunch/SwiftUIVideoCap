//
//  ContentView.swift
//  SwiftUIVideoCap
//
//  Created by Edward Janne on 5/30/22.
//

import SwiftUI
import AVFoundation

let videoCapture = VideoCapture()

let sharedContext = CIContext(options: [.useSoftwareRenderer: false])

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
    @State var scale: Double = 0.333333333
    
    // The currently captured frame as an NSImage
    @State private var nsImage = NSImage()
    
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
                        
                        // Attach a closure to the videoCapture object  handle incoming frames
                        videoCapture
                            .onCapturedImage { buffer in
                                if let buffer = buffer {
                                    // Get the dimensions of the image
                                    let width = CVPixelBufferGetWidth(buffer)
                                    let height = CVPixelBufferGetHeight(buffer)
                                    var bounds = CGRect(x: 0, y: 0, width: width, height: height)
                                    // Create a CoreImage image class with the buffer
                                    var ciImage = CIImage(cvImageBuffer: buffer)
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
}
