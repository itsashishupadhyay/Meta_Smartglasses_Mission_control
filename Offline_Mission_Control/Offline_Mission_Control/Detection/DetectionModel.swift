//
//  DetectionModel.swift
//  Offline_Mission_Control
//
//  The catalogue of selectable on-device detection models. Each entry maps to a compiled
//  Core ML model bundled under Resources/ (produced by tools/convert_models.py). Availability
//  is resolved at runtime from the app bundle, so the picker can show which models are present
//  and which still need to be generated.
//

import Foundation

struct DetectionModelOption: Identifiable, Sendable, Equatable {
    let id: String
    /// Display name shown in the picker and status chip.
    let displayName: String
    /// Base name of the compiled model in the bundle (.mlpackage → .mlmodelc).
    let resourceName: String
    let dataset: String
    let classCount: Int
    /// One-line "when to choose this" guidance shown under the name.
    let useCase: String
    let approxSize: String
    let systemImage: String

    /// Whether the compiled model is actually present in the app bundle.
    var isAvailable: Bool {
        Bundle.main.url(forResource: resourceName, withExtension: "mlmodelc") != nil
            || Bundle.main.url(forResource: resourceName, withExtension: "mlmodel") != nil
    }
}

extension DetectionModelOption {
    static let defaultID = "yolov8n-coco"

    static let all: [DetectionModelOption] = [
        DetectionModelOption(
            id: "yolov8n-coco",
            displayName: "YOLOv8n",
            resourceName: "YOLOv8n",
            dataset: "COCO",
            classCount: 80,
            useCase: "Fastest and lightest. Best for smooth, high-frame-rate detection and battery life on common, everyday objects.",
            approxSize: "~6 MB",
            systemImage: "bolt.fill"
        ),
        DetectionModelOption(
            id: "yolo11l-coco",
            displayName: "YOLO11l",
            resourceName: "YOLO11l",
            dataset: "COCO",
            classCount: 80,
            useCase: "Highest accuracy on the same 80 everyday objects. Heavier per frame — pair with a higher “Appear For” dwell.",
            approxSize: "~50 MB",
            systemImage: "scope"
        ),
        DetectionModelOption(
            id: "yolov8m-oiv7",
            displayName: "YOLOv8m · Open Images",
            resourceName: "YOLOv8m-OIV7",
            dataset: "Open Images V7",
            classCount: 600,
            useCase: "Recognises 600 categories — far beyond COCO’s basics. Choose when you want the glasses to identify a wide variety of things.",
            approxSize: "~50 MB",
            systemImage: "circle.grid.3x3.fill"
        ),
        DetectionModelOption(
            id: "yolov8x-oiv7",
            displayName: "YOLOv8x · Open Images",
            resourceName: "YOLOv8x-OIV7",
            dataset: "Open Images V7",
            classCount: 600,
            useCase: "Maximum coverage and accuracy across 600 categories. Bulky and slowest — for stationary, detail-critical scanning.",
            approxSize: "~130 MB",
            systemImage: "circle.hexagongrid.fill"
        ),
    ]

    static func option(for id: String) -> DetectionModelOption {
        all.first { $0.id == id } ?? all.first { $0.id == defaultID } ?? all[0]
    }

    /// The first bundled model, preferring the default — used as a safe fallback.
    static var firstAvailable: DetectionModelOption? {
        if let def = all.first(where: { $0.id == defaultID && $0.isAvailable }) { return def }
        return all.first { $0.isAvailable }
    }
}
