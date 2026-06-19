//
//  ScanView.swift
//  Mediflow
//
//  Created by vishruth on 31/5/2026.
//

import SwiftUI
import Vision
import AVFoundation

struct ScanView: View {
    @State private var capturedImage: UIImage? = nil
    @State private var scannedText = ""
    
    var body: some View {
        VStack {
            VStack(spacing: 8) {
                Text("Scanner")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.top, 4)
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
                
                // Live camera stream frame
                EmbeddedCameraView(capturedImage: $capturedImage)
                    .cornerRadius(20)
                
                // Overlays captured image freeze-frame if shot taken
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(20)
                        .padding(8)
                }
            }
            .padding()
            .frame(minHeight: 530)
            
            // Scrollable Scanned Text Box Block
            if !scannedText.isEmpty {
                ScrollView {
                    Text(scannedText)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .frame(maxHeight: 120)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            VStack {
                Button(action: {
                    if capturedImage != nil {
                        // Reset screen layout for another scan
                        capturedImage = nil
                        scannedText = ""
                    } else {
                        // Trigger active photo capture logic
                        NotificationCenter.default.post(name: NSNotification.Name("TriggerCapture"), object: nil)
                    }
                }) {
                    Image(systemName: capturedImage == nil ? "camera.circle.fill" : "arrow.clockwise.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(.blue)
                }
                .padding(.bottom, 24)
            }
        }
        .onChange(of: capturedImage) { oldValue, newValue in
            if let image = newValue {
                recognizeText(from: image)
            }
        }
    }
    

    func recognizeText(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let text = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            DispatchQueue.main.async {
                self.scannedText = text
            }
        }
        
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
}

struct EmbeddedCameraView: UIViewRepresentable {
    @Binding var capturedImage: UIImage?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 530))
        context.coordinator.setupSession(in: view)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        var parent: EmbeddedCameraView
        let session = AVCaptureSession()
        let photoOutput = AVCapturePhotoOutput()
        
        init(parent: EmbeddedCameraView) {
            self.parent = parent
        }
        
        func setupSession(in view: UIView) {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            
            session.beginConfiguration()
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            session.commitConfiguration()
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
            
            NotificationCenter.default.addObserver(self, selector: #selector(capturePhoto), name: NSNotification.Name("TriggerCapture"), object: nil)
        }
        
        @objc func capturePhoto() {
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.parent.capturedImage = image
            }
        }
    }
}

#Preview {
    ScanView()
}
