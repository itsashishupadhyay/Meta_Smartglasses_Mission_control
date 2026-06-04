//
//  DetectionAggregator.swift
//  Offline_Mission_Control
//
//  Turns a frame's raw detections into a compact, ordered summary used by both
//  the glasses HUD card and the spoken announcements (e.g. "person ×1 · car ×2").
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

    /// One-line HUD/string summary, e.g. "person ×1 · car ×2".
    static func summaryLine(_ summary: [ClassCount], limit: Int = 4) -> String {
        guard !summary.isEmpty else { return "No objects detected" }
        return summary.prefix(limit)
            .map { $0.count > 1 ? "\($0.label) ×\($0.count)" : $0.label }
            .joined(separator: " · ")
    }
}
