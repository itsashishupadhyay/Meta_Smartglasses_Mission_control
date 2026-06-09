//
//  Mission.swift
//  Offline_Mission_Control
//
//  Codable model for a mission-log state machine (e.g. ISS_RGA_RnR_state_machine.json).
//  Each state maps a procedure step to a COCO-proxy object trigger, a spoken cue, an expected
//  spoken indication, an estimated time, and on-confirm / on-anomaly transitions.
//

import Foundation

struct Mission: Codable, Sendable {
    let schemaVersion: String?
    let procedure: ProcedureInfo
    let cocoProxyLegend: [ProxyLegendEntry]?
    let startState: String
    let endState: String?
    let states: [MissionState]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case procedure
        case cocoProxyLegend = "coco_proxy_legend"
        case startState = "start_state"
        case endState = "end_state"
        case states
    }
}

struct ProcedureInfo: Codable, Sendable {
    let id: String?
    let title: String
    let discipline: String?
    let worksite: String?
    let crew: String?
    let objective: String?
    let classification: String?
    let estTotalTimeMin: Int?
    let warnings: [String]?

    enum CodingKeys: String, CodingKey {
        case id, title, discipline, worksite, crew, objective, classification
        case estTotalTimeMin = "est_total_time_min"
        case warnings
    }
}

struct ProxyLegendEntry: Codable, Sendable, Identifiable {
    var id: String { cocoClass + represents }
    let represents: String
    let cocoClass: String
    let cocoId: Int?

    enum CodingKeys: String, CodingKey {
        case represents
        case cocoClass = "coco_class"
        case cocoId = "coco_id"
    }
}

enum StateType: String, Codable, Sendable {
    case task, gate, contingency, terminal
    case getAhead = "get_ahead"
}

struct MissionState: Codable, Sendable, Identifiable {
    var id: String { stateID }
    let stateID: String
    let type: StateType
    let section: String?
    let taskName: String
    let crew: String?
    let objectTrigger: [ObjectTrigger]
    let approxTimeMin: Int
    let expectedIndication: String?
    let messageLog: String
    let onConfirm: String?
    let onAnomaly: String?
    let optional: Bool?
    let triggerCondition: String?

    enum CodingKeys: String, CodingKey {
        case stateID = "id"
        case type, section, crew, optional
        case taskName = "task_name"
        case objectTrigger = "object_trigger"
        case approxTimeMin = "approx_time_min"
        case expectedIndication = "expected_indication"
        case messageLog = "message_log"
        case onConfirm = "on_confirm"
        case onAnomaly = "on_anomaly"
        case triggerCondition = "trigger_condition"
    }
}

struct ObjectTrigger: Codable, Sendable {
    /// The COCO class string — the MATCH KEY against `Detection.label`.
    let cocoClass: String
    let cocoId: Int?
    let represents: String?
    let confidenceMin: Float?

    enum CodingKeys: String, CodingKey {
        case cocoClass = "coco_class"
        case cocoId = "coco_id"
        case represents
        case confidenceMin = "confidence_min"
    }
}

// MARK: - Derived helpers

extension Mission {
    func state(id: String) -> MissionState? { states.first { $0.stateID == id } }

    var legend: [ProxyLegendEntry] { cocoProxyLegend ?? [] }

    /// The nominal path — from `start_state` following `on_confirm` to the end — which forms the
    /// ordered, swipeable set of cue cards. Contingency / get-ahead states are off this line and
    /// are spliced in only when entered.
    var nominalLine: [MissionState] {
        var line: [MissionState] = []
        var seen = Set<String>()
        var cursor: String? = startState
        while let id = cursor, !seen.contains(id), let s = state(id: id) {
            seen.insert(id)
            line.append(s)
            cursor = s.onConfirm
        }
        return line
    }

    /// Steps that count toward "N of total" — nominal task + gate states (excludes terminal,
    /// contingency, and optional get-aheads).
    var nominalStepCount: Int {
        nominalLine.filter { $0.type == .task || $0.type == .gate }.count
    }
}
