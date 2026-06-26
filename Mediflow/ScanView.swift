import SwiftUI
import Vision
import AVFoundation
import PhotosUI

struct ScannedMedication {
    var name: String = ""
    var dose: String = ""
    var type: String = ""
    var icon: String = "pill"
    var frequency: Int16 = 1
    var intervalDays: Int16 = 1
    var timesPerDay: Int = 1
    var hasEndDate: Bool = false
    var durationDays: Int? = nil
}

struct ScanView: View {
    @Environment(\.managedObjectContext) var viewContext

    @State private var capturedImage: UIImage? = nil
    @State private var scannedText = ""
    @State private var isProcessing = false
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var parsedMed: ScannedMedication? = nil
    @State private var showForm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Scanner")
                    .font(.system(size: 38, weight: .bold))
                    .padding(.top, 8)
                    .padding(.horizontal)
                Spacer()
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                        .padding(.top, 8)
                        .padding(.trailing)
                }
                .onChange(of: photoPickerItem) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            capturedImage = image
                        }
                    }
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))

                EmbeddedCameraView(capturedImage: $capturedImage)
                    .cornerRadius(20)

                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(20)
                        .padding(8)
                }

                if isProcessing {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.45))
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.4)
                            Text("Reading prescription…")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding()
            .frame(minHeight: 420)

            if !scannedText.isEmpty && !isProcessing {
                ScrollView {
                    Text(scannedText)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .frame(maxHeight: 100)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            Spacer()

            HStack(spacing: 40) {
                if capturedImage != nil {
                    Button {
                        capturedImage = nil
                        scannedText = ""
                        parsedMed = nil
                        photoPickerItem = nil
                    } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                    }
                }

                Button {
                    if capturedImage == nil {
                        NotificationCenter.default.post(name: NSNotification.Name("TriggerCapture"), object: nil)
                    }
                } label: {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(capturedImage == nil ? .blue : .blue.opacity(0.3))
                }
                .disabled(capturedImage != nil)
            }
            .padding(.bottom, 28)
        }
        .onChange(of: capturedImage) { _, image in
            guard let image else { return }
            recognizeText(from: image)
        }
        .sheet(isPresented: $showForm) {
            if let med = parsedMed {
                NavigationStack {
                    Medication_form(scannedData: med)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
    }

    func recognizeText(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        isProcessing = true

        let request = VNRecognizeTextRequest { request, _ in
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let text = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")

            DispatchQueue.main.async {
                self.scannedText = text
                self.parsedMed = PrescriptionParser.parse(text)
                self.isProcessing = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.showForm = true
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}

struct PrescriptionParser {

    static func parse(_ text: String) -> ScannedMedication {
        var result = ScannedMedication()
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let lower = text.lowercased()

        for line in lines {
            let stripped = line.trimmingCharacters(in: .punctuationCharacters)
            if stripped.isEmpty { continue }
            if stripped.range(of: #"^\d+[/\-]\d+"#, options: .regularExpression) != nil { continue }
            if stripped.range(of: #"^\d+$"#, options: .regularExpression) != nil { continue }
            let skip = ["pharmacy","dispensed","qty","quantity","refill","date","patient","dr ","doctor","prescription","rx","form","type","route"]
            if skip.contains(where: { stripped.lowercased().hasPrefix($0) }) { continue }
            result.name = stripped
            break
        }

        let dosePattern = #"(\d+(?:\.\d+)?\s*(?:mg|mcg|ml|g|tablet|tablets|cap|capsule|capsules|unit|units|iu|puff|puffs))"#
        if let match = text.range(of: dosePattern, options: [.regularExpression, .caseInsensitive]) {
            result.dose = String(text[match])
        }

        let typeMap: [(String, String)] = [
            ("antibiotic|amoxicillin|azithromycin|penicillin|cefalexin", "Antibiotic"),
            ("antiviral|aciclovir|oseltamivir|valaciclovir", "Antiviral"),
            ("antifungal|fluconazole|clotrimazole", "Antifungal"),
            ("pain|paracetamol|ibuprofen|codeine|analgesic|panadol|nurofen", "Pain reliever"),
            ("fever|antipyretic", "Fever reducer"),
            ("antihistamine|cetirizine|loratadine|fexofenadine", "Antihistamine"),
            ("vitamin|vit ", "Vitamin"),
            ("supplement|mineral|omega|probiotic", "Supplement"),
        ]
        for (pattern, typeName) in typeMap {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                result.type = typeName
                break
            }
        }

        let iconMap: [(String, String)] = [
            ("capsule", "pill.fill"),
            ("tablet|pill", "pill"),
            ("liquid|syrup|suspension|solution|ml", "waterbottle"),
            ("chewable|chew", "circle.lefthalf.filled"),
            ("gummy|gummies", "capsule.on.capsule"),
            ("injection|vial|syringe", "syringe"),
        ]
        for (pattern, icon) in iconMap {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                result.icon = icon
                break
            }
        }

        if lower.range(of: #"three times|3\s*times|thrice"#, options: .regularExpression) != nil {
            result.frequency = 2
            result.timesPerDay = 3
        } else if lower.range(of: #"twice|two times|2\s*times|b\.?i\.?d\.?"#, options: .regularExpression) != nil {
            result.frequency = 2
            result.timesPerDay = 2
        } else if lower.range(of: #"four times|4\s*times|q\.?i\.?d\.?"#, options: .regularExpression) != nil {
            result.frequency = 2
            result.timesPerDay = 4
        } else if lower.range(of: #"every\s+(\d+)\s+day"#, options: .regularExpression) != nil {
            result.frequency = 4
            if let m = lower.range(of: #"every\s+(\d+)\s+day"#, options: .regularExpression) {
                let sub = String(lower[m])
                if let n = sub.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap({ Int($0) }).first {
                    result.intervalDays = Int16(n)
                }
            }
        } else if lower.range(of: #"weekly|once a week|per week"#, options: .regularExpression) != nil {
            result.frequency = 3
        } else if lower.range(of: #"once only|one time|stat\b|single dose"#, options: .regularExpression) != nil {
            result.frequency = 0
        } else if lower.range(of: #"once daily|daily|every day|each day|o\.?d\.?|per day|a day"#, options: .regularExpression) != nil {
            result.frequency = 1
        }

        let durationPatterns: [(String, Int)] = [
            (#"for\s+(\d+)\s+day"#, 1),
            (#"for\s+(\d+)\s+week"#, 7),
            (#"for\s+(\d+)\s+month"#, 30),
        ]
        for (pattern, multiplier) in durationPatterns {
            if let m = lower.range(of: pattern, options: .regularExpression) {
                let sub = String(lower[m])
                if let n = sub.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap({ Int($0) }).first {
                    result.durationDays = n * multiplier
                    result.hasEndDate = true
                    break
                }
            }
        }

        return result
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

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        var parent: EmbeddedCameraView
        let session = AVCaptureSession()
        let photoOutput = AVCapturePhotoOutput()

        init(parent: EmbeddedCameraView) { self.parent = parent }

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

            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
            NotificationCenter.default.addObserver(self, selector: #selector(capturePhoto),
                                                   name: NSNotification.Name("TriggerCapture"), object: nil)
        }

        @objc func capturePhoto() {
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }

        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { self.parent.capturedImage = image }
        }
    }
}

#Preview {
    ScanView()
}
