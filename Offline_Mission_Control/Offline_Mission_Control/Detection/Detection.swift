//
//  Detection.swift
//  Offline_Mission_Control
//
//  A single object-detection result. Bounding boxes use Vision's convention:
//  normalized [0,1] coordinates with the origin at the BOTTOM-left of the image.
//  Convert to a top-left UIKit/SwiftUI rect when drawing (see BoundingBoxLayer).
//

import CoreGraphics
import Foundation

struct Detection: Identifiable, Sendable, Equatable {
    let id = UUID()
    /// Class label, e.g. "person", "car".
    let label: String
    /// Confidence in [0,1].
    let confidence: Float
    /// Normalized bounding box (Vision convention: origin bottom-left).
    let boundingBox: CGRect

    static func == (lhs: Detection, rhs: Detection) -> Bool {
        lhs.id == rhs.id
    }
}

extension Detection {
    /// "person 92%"
    var displayText: String {
        "\(label) \(Int((confidence * 100).rounded()))%"
    }
}
