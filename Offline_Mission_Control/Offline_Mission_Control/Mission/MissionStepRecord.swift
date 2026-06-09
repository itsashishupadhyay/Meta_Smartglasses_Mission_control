//
//  MissionStepRecord.swift
//  Offline_Mission_Control
//
//  One completed step's entry in the post-mission report: timing, how long the target object was
//  in view, how it was confirmed (voice transcript / manual / override), and a captured snapshot
//  of the target while it was visible (nil if it was never seen — e.g. a manual override).
//

import SwiftUI

enum StepConfirmation {
    case voice(String)   // the heard transcript that matched
    case manual          // Confirm button
    case `override`      // "confirmed override" cheat phrase

    var label: String {
        switch self {
        case .voice: "Voice"
        case .manual: "Manual"
        case .override: "Override"
        }
    }
    var transcript: String? {
        if case let .voice(text) = self { return text }
        return nil
    }
}

struct MissionStepRecord: Identifiable {
    var id: String { stateID }
    let stateID: String
    let taskName: String
    let section: String?
    let confirmedAt: Date
    /// Time spent on the step (from when it became active to confirmation).
    let duration: TimeInterval
    /// How long the target object was detected in view while the step was active.
    let targetSeenSeconds: TimeInterval
    let confirmation: StepConfirmation
    let snapshot: UIImage?
}
