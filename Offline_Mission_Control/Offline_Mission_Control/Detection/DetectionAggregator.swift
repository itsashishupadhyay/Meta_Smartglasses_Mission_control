//
//  DetectionAggregator.swift
//  Offline_Mission_Control
//
//  Turns a frame's raw detections into a compact, ordered summary (ranked [ClassCount])
//  used by the live "Detected" list and the spoken announcements.
//

import Foundation

struct ClassCount: Identifiable, Sendable, Equatable {
    var id: String { label }
    let label: String
    let count: Int
    /// Highest confidence seen for this label in the frame.
    let topConfidence: Float
}

enum DetectionAggregator {
    /// Group detections by label, ordered by count (desc) then confidence (desc).
    static func summarize(_ detections: [Detection]) -> [ClassCount] {
        guard !detections.isEmpty else { return [] }
        var counts: [String: (count: Int, top: Float)] = [:]
        for d in detections {
            let existing = counts[d.label] ?? (0, 0)
            counts[d.label] = (existing.count + 1, max(existing.top, d.confidence))
        }
        return counts
            .map { ClassCount(label: $0.key, count: $0.value.count, topConfidence: $0.value.top) }
            .sorted { lhs, rhs in
                lhs.count != rhs.count ? lhs.count > rhs.count : lhs.topConfidence > rhs.topConfidence
            }
    }
}
