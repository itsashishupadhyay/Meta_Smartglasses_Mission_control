//
//  AppSettings.swift
//  Offline_Mission_Control
//
//  User-tunable, persisted settings for the glasses camera and the detection pipeline.
//  Persists to UserDefaults and notifies the orchestrator (via the `…Changed` hooks) so it
//  can push camera-config changes to the live stream and update the detector/announcer.
//
//  The camera exposes resolution and frame rate here (modelled as friendly options); the
//  video codec is fixed to RAW for the cleanest detection input.
//

import MWDATCamera
import Observation
import SwiftUI

// MARK: - Camera options

enum CameraResolutionOption: String, CaseIterable, Identifiable, Sendable {
    case high, medium, low
    var id: String { rawValue }

    var title: String {
        switch self {
        case .high: "High Detail"
        case .medium: "Balanced"
        case .low: "Power Saver"
        }
    }

    var systemImage: String {
        switch self {
        case .high: "arrow.up.circle.fill"
        case .medium: "equal.circle.fill"
        case .low: "arrow.down.circle.fill"
        }
    }

    var streamingResolution: StreamingResolution {
        switch self {
        case .high: .high
        case .medium: .medium
        case .low: .low
        }
    }

    /// Live pixel dimensions reported by the SDK, e.g. "1280 × 960".
    var dimensionsText: String {
        let size = streamingResolution.videoFrameSize
        return "\(size.width) × \(size.height)"
    }

    /// Compact label for the on-camera status pill, e.g. "960p".
    var shortLabel: String {
        "\(streamingResolution.videoFrameSize.height)p"
    }
}

// MARK: - Mission Logs options

/// How leniently a spoken call-out must match a step's `expected_indication` to advance.
enum MissionMatchStrictness: String, CaseIterable, Identifiable, Sendable {
    case strict, balanced, lenient
    var id: String { rawValue }

    var title: String {
        switch self {
        case .strict: "Strict"
        case .balanced: "Balanced"
        case .lenient: "Lenient"
        }
    }
    var subtitle: String {
        switch self {
        case .strict: "Say it almost exactly"
        case .balanced: "Hit most of the key words"
        case .lenient: "A few key words are enough"
        }
    }
    /// Recall threshold (fraction of the expected keywords that must be heard).
    var threshold: Double {
        switch self {
        case .strict: 0.6
        case .balanced: 0.4
        case .lenient: 0.25
        }
    }
    /// Minimum absolute keyword hits.
    var minHits: Int {
        switch self {
        case .strict, .balanced: 2
        case .lenient: 1
        }
    }
}

// MARK: - Settings store

@Observable
@MainActor
final class AppSettings {
    /// Selectable camera frame-rate presets (fps).
    static let frameRatePresets = [5, 10, 15, 20, 30]

    // Camera
    var resolution: CameraResolutionOption {
        didSet { defaults.set(resolution.rawValue, forKey: Keys.resolution); cameraConfigChanged?() }
    }
    var frameRate: Int {
        didSet { defaults.set(frameRate, forKey: Keys.frameRate); cameraConfigChanged?() }
    }

    // Detection
    /// Selected on-device model (see DetectionModelOption.all).
    var modelID: String {
        didSet { defaults.set(modelID, forKey: Keys.model); modelChanged?() }
    }
    var confidence: Double {
        didSet { defaults.set(confidence, forKey: Keys.confidence); confidenceChanged?(Float(confidence)) }
    }
    /// Seconds an object class must persist before it's shown + announced. 0 = every frame.
    var dwellSeconds: Double {
        didSet { defaults.set(dwellSeconds, forKey: Keys.dwell); dwellChanged?(dwellSeconds) }
    }
    /// Minimum spacing between repeated announcements of the same class.
    var reannounceSeconds: Double {
        didSet { defaults.set(reannounceSeconds, forKey: Keys.reannounce); reannounceChanged?(reannounceSeconds) }
    }
    /// How often the spoken glasses recap fires (seconds).
    var recapIntervalSeconds: Double {
        didSet { defaults.set(recapIntervalSeconds, forKey: Keys.recapInterval) }
    }
    /// File name of the selected mission-log JSON (empty = none chosen yet).
    var selectedMissionFileName: String {
        didSet { defaults.set(selectedMissionFileName, forKey: Keys.mission) }
    }
    /// Voice-confirmation match strictness (raw value of `MissionMatchStrictness`).
    var missionMatchStrictness: String {
        didSet { defaults.set(missionMatchStrictness, forKey: Keys.missionStrictness) }
    }
    var missionStrictness: MissionMatchStrictness {
        MissionMatchStrictness(rawValue: missionMatchStrictness) ?? .balanced
    }
    /// Target-detection confidence override for missions. 0 = use the JSON's per-trigger value.
    var missionConfidence: Double {
        didSet { defaults.set(missionConfidence, forKey: Keys.missionConfidence) }
    }
    /// Target-detection "appear for" dwell override for missions (seconds). 0 = use the global dwell.
    var missionDwellSeconds: Double {
        didSet { defaults.set(missionDwellSeconds, forKey: Keys.missionDwell) }
    }

    // Change hooks (installed by the orchestrator; not observed/persisted).
    @ObservationIgnored var cameraConfigChanged: (() -> Void)?
    @ObservationIgnored var confidenceChanged: ((Float) -> Void)?
    @ObservationIgnored var dwellChanged: ((Double) -> Void)?
    @ObservationIgnored var reannounceChanged: ((Double) -> Void)?
    @ObservationIgnored var modelChanged: (() -> Void)?

    /// Resolved model option for the persisted `modelID`.
    var selectedModel: DetectionModelOption { DetectionModelOption.option(for: modelID) }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let resolution = "cam.resolution"
        static let frameRate = "cam.frameRate"
        static let model = "det.model"
        static let confidence = "det.confidence"
        static let dwell = "det.dwellSeconds"
        static let reannounce = "det.reannounceSeconds"
        static let recapInterval = "det.hudUpdateSeconds" // legacy key string preserved for migration
        static let mission = "mission.selectedFile"
        static let missionStrictness = "mission.strictness"
        static let missionConfidence = "mission.confidence"
        static let missionDwell = "mission.dwellSeconds"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // didSet observers do NOT fire during init, so these loads have no side effects.
        resolution = CameraResolutionOption(rawValue: defaults.string(forKey: Keys.resolution) ?? "") ?? .medium
        frameRate = defaults.object(forKey: Keys.frameRate) != nil ? defaults.integer(forKey: Keys.frameRate) : 15
        modelID = defaults.string(forKey: Keys.model) ?? DetectionModelOption.defaultID
        confidence = defaults.object(forKey: Keys.confidence) != nil ? defaults.double(forKey: Keys.confidence) : 0.35
        dwellSeconds = defaults.object(forKey: Keys.dwell) != nil ? defaults.double(forKey: Keys.dwell) : 0
        reannounceSeconds = defaults.object(forKey: Keys.reannounce) != nil ? defaults.double(forKey: Keys.reannounce) : 4.0
        recapIntervalSeconds = defaults.object(forKey: Keys.recapInterval) != nil ? defaults.double(forKey: Keys.recapInterval) : 15
        selectedMissionFileName = defaults.string(forKey: Keys.mission) ?? ""
        missionMatchStrictness = defaults.string(forKey: Keys.missionStrictness) ?? MissionMatchStrictness.balanced.rawValue
        missionConfidence = defaults.double(forKey: Keys.missionConfidence)   // default 0 = use JSON
        missionDwellSeconds = defaults.double(forKey: Keys.missionDwell)      // default 0 = instant
    }
}
