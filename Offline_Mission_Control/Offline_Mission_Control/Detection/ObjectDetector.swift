//
//  ObjectDetector.swift
//  Offline_Mission_Control
//
//  On-device YOLO object detection via Core ML + Vision. Runs on its own actor so
//  inference stays OFF the main thread (the project default-isolates to MainActor).
//
//  The model (`YOLOv8n.mlpackage`) is produced by tools/convert_yolo_to_coreml.py with
//  NMS baked in, so Vision returns `VNRecognizedObjectObservation`s (label + box) and
//  we don't have to decode raw tensors or run NMS ourselves.
//
//  The model is loaded dynamically from the bundle by name, so the app still compiles
//  and runs (showing a clear "model missing" status) before the .mlpackage is added.
//

import CoreML
import CoreGraphics
import Foundation
import Vision

/// Result of attempting to load/run the detector.
enum DetectorStatus: Sendable, Equatable {
    case notLoaded
    case ready
    case modelMissing
    case failed(String)
}

actor ObjectDetector {
    /// Resource name of the compiled model in the app bundle (.mlpackage -> .mlmodelc).
    private var modelResourceName: String
    private var visionModel: VNCoreMLModel?
    private(set) var status: DetectorStatus = .notLoaded

    /// Minimum confidence for a detection to be reported.
    var confidenceThreshold: Float = 0.35

    init(modelResourceName: String = "YOLOv8n") {
        self.modelResourceName = modelResourceName
    }

    func setConfidenceThreshold(_ value: Float) {
        confidenceThreshold = min(max(value, 0), 1)
    }

    /// Switch to a different bundled model and (re)load it. Returns the resulting status.
    @discardableResult
    func setModel(_ resourceName: String) -> DetectorStatus {
        if resourceName == modelResourceName, case .ready = status { return status }
        modelResourceName = resourceName
        visionModel = nil
        status = .notLoaded
        return prepare()
    }

    /// Loads the Core ML model (idempotent). Returns the resulting status.
    @discardableResult
    func prepare() -> DetectorStatus {
        if case .ready = status { return status }

        guard let url = compiledModelURL() else {
            status = .modelMissing
            return status
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all // Neural Engine + GPU + CPU
            let mlModel = try MLModel(contentsOf: url, configuration: config)
            visionModel = try VNCoreMLModel(for: mlModel)
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
        return status
    }

    /// Run detection on a single frame. `cgImage` is `sending` so it can cross from the
    /// MainActor (where frames arrive) into this actor without a Sendable violation.
    func detect(
        _ cgImage: sending CGImage,
        orientation: CGImagePropertyOrientation = .up
    ) -> [Detection] {
        if visionModel == nil { prepare() }
        guard let visionModel else { return [] }

        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        let observations = (request.results as? [VNRecognizedObjectObservation]) ?? []
        let threshold = confidenceThreshold
        return observations.compactMap { obs -> Detection? in
            guard let top = obs.labels.first, top.confidence >= threshold else { return nil }
            return Detection(
                label: top.identifier,
                confidence: top.confidence,
                boundingBox: obs.boundingBox
            )
        }
    }

    // MARK: - Private

    private func compiledModelURL() -> URL? {
        // Xcode compiles .mlpackage -> .mlmodelc in the bundle.
        if let url = Bundle.main.url(forResource: modelResourceName, withExtension: "mlmodelc") {
            return url
        }
        // Fallback: a precompiled .mlmodel that hasn't been ahead-of-time compiled.
        if let raw = Bundle.main.url(forResource: modelResourceName, withExtension: "mlmodel") {
            return try? MLModel.compileModel(at: raw)
        }
        return nil
    }
}
