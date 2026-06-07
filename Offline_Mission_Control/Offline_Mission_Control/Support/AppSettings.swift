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

    // Change hooks (installed by the orchestrator; not observed/persisted).
    @ObservationIgnored var cameraConfigChanged: (() -> Void)?
    @ObservationIgnored var confidenceChanged: ((Float) -> Void)?
    @ObservationIgnored var dwellChanged: ((Double) -> Void)?
    @ObservationIgnored var reannounceChanged: ((Double) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let resolution = "cam.resolution"
        static let frameRate = "cam.frameRate"
        static let confidence = "det.confidence"
        static let dwell = "det.dwellSeconds"
        static let reannounce = "det.reannounceSeconds"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // didSet observers do NOT fire during init, so these loads have no side effects.
        resolution = CameraResolutionOption(rawValue: defaults.string(forKey: Keys.resolution) ?? "") ?? .medium
        frameRate = defaults.object(forKey: Keys.frameRate) != nil ? defaults.integer(forKey: Keys.frameRate) : 15
        confidence = defaults.object(forKey: Keys.confidence) != nil ? defaults.double(forKey: Keys.confidence) : 0.35
        dwellSeconds = defaults.object(forKey: Keys.dwell) != nil ? defaults.double(forKey: Keys.dwell) : 0
        reannounceSeconds = defaults.object(forKey: Keys.reannounce) != nil ? defaults.double(forKey: Keys.reannounce) : 4.0
    }
}
