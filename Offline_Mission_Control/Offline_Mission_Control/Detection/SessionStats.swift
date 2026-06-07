//
//  SessionStats.swift
//  Offline_Mission_Control
//
//  Per-session detection accounting that backs the "leaderboard" panel: for the span between
//  Start and Stop it tracks, per object class, how many detection frames it appeared in and —
//  derived from the session's effective frame rate — how long that adds up to (MM:SS). Also
//  exposes the live session elapsed time.
//

import Foundation
import Observation

struct ObjectSessionStat: Identifiable, Sendable, Equatable {
    var id: String { label }
    let label: String
    var frames: Int
    var firstSeen: TimeInterval   // session-relative seconds
    var lastSeen: TimeInterval
}

@Observable
@MainActor
final class SessionStatsTracker {
    /// Objects ranked by how many frames they were detected in (descending).
    private(set) var leaderboard: [ObjectSessionStat] = []
    /// Live elapsed time since the session started.
    private(set) var elapsed: TimeInterval = 0
    /// Total detection frames processed this session.
    private(set) var totalFrames: Int = 0
    /// True once a session has begun (stays true after stop so the final log can be reviewed).
    private(set) var hasData: Bool = false

    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var byLabel: [String: ObjectSessionStat] = [:]

    /// Detection frames per second across the whole session (used to convert frames → time).
    var effectiveFPS: Double {
        elapsed > 0.001 ? Double(totalFrames) / elapsed : 0
    }

    var maxFrames: Int { leaderboard.first?.frames ?? 0 }

    func start(now: Date = Date()) {
        startedAt = now
        byLabel = [:]
        leaderboard = []
        elapsed = 0
        totalFrames = 0
        hasData = true
    }

    func reset() {
        startedAt = nil
        byLabel = [:]
        leaderboard = []
        elapsed = 0
        totalFrames = 0
        hasData = false
    }

    /// Record one processed detection frame and the unique object labels visible in it.
    func recordFrame(labels: Set<String>, now: Date = Date()) {
        guard let startedAt else { return }
        elapsed = now.timeIntervalSince(startedAt)
        totalFrames += 1
        for label in labels {
            if var stat = byLabel[label] {
                stat.frames += 1
                stat.lastSeen = elapsed
                byLabel[label] = stat
            } else {
                byLabel[label] = ObjectSessionStat(label: label, frames: 1, firstSeen: elapsed, lastSeen: elapsed)
            }
        }
        leaderboard = byLabel.values.sorted {
            $0.frames != $1.frames ? $0.frames > $1.frames : $0.firstSeen < $1.firstSeen
        }
    }

    /// Keep the live timer advancing even if frames momentarily stop arriving.
    func tick(now: Date = Date()) {
        guard let startedAt else { return }
        elapsed = now.timeIntervalSince(startedAt)
    }

    /// Cumulative time (seconds) an object was detected, derived from its frame count and the
    /// session's effective frame rate.
    func detectedTime(_ stat: ObjectSessionStat) -> TimeInterval {
        effectiveFPS > 0 ? Double(stat.frames) / effectiveFPS : 0
    }

    /// Format a duration as MM:SS.
    static func mmss(_ time: TimeInterval) -> String {
        let total = max(0, Int(time.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
