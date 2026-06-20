// CameraPreview.swift

import SwiftUI
import AVFoundation
import Combine

 private final class CameraPreviewModel: ObservableObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "CameraPreview.session.queue")

    func start() {
        sessionQueue.async {
            if self.session.inputs.isEmpty {
                self.configureSession()
            }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()
    }
}

struct CameraPreview: View {
    @StateObject private var model = CameraPreviewModel()

    var body: some View {
        ZStack {
            CameraPreviewLayer(session: model.session)
                .onAppear { model.start() }
                .onDisappear { model.stop() }
                .clipped()
        }
        .background(Color.black)
        .accessibilityLabel("Live camera preview")
    }
}

private struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

