//
//  DetectionStabilizer.swift
//  Offline_Mission_Control
//
//  Temporal gate for detections. A class label must remain present for at least
//  `dwellSeconds` before it is "confirmed" — i.e. eligible to be drawn, listed, announced,
//  and sent to the glasses HUD. This removes single-frame flicker/false positives and gives
//  a calm, stable read-out. `dwellSeconds == 0` reproduces the original per-frame behaviour.
//
//  A short grace window absorbs brief 1–2 frame dropouts so a steadily-visible object doesn't
//  have its dwell timer reset by momentary detector misses.
//

import Foundation

@MainActor
final class DetectionStabilizer {
    /// Seconds a label must persist before it is confirmed. 0 = confirm immediately.
    var dwellSeconds: TimeInterval = 0

    /// Tolerated gap (seconds) before a label's dwell timer is considered broken.
    private let graceGap: TimeInterval = 0.5

    private var firstSeen: [String: TimeInterval] = [:]
    private var lastSeen: [String: TimeInterval] = [:]

    /// Returns the set of labels that are present in this frame AND have persisted long enough.
    func confirmedLabels(in detections: [Detection], now: TimeInterval) -> Set<String> {
        let present = Set(detections.map(\.label))

        // Expire labels not seen within the grace window so their dwell timer restarts cleanly.
        for (label, seen) in lastSeen where now - seen > graceGap {
            firstSeen[label] = nil
            lastSeen[label] = nil
        }

        // Register newly-seen labels and refresh the ones present this frame.
        for label in present {
            if firstSeen[label] == nil { firstSeen[label] = now }
            lastSeen[label] = now
        }

        guard dwellSeconds > 0 else { return present }
        return present.filter { label in
            guard let first = firstSeen[label] else { return false }
            return now - first >= dwellSeconds
        }
    }

    func reset() {
        firstSeen.removeAll()
        lastSeen.removeAll()
    }
}
