//
//  MissionControlViewModel.swift
//  Offline_Mission_Control
//
//  Orchestrates the full pipeline:
//    glasses camera frame -> Core ML detector (off-main actor) -> phone overlay + leaderboard,
//    plus a periodic spoken recap to the glasses' Bluetooth speakers.
//

import CoreGraphics
import MWDATCore
import Observation
import SwiftUI

@Observable
@MainActor
final class MissionControlViewModel {
    // Sub-systems
    let wearables: WearablesManager
    let camera: GlassesCameraService
    let motion: MotionService
    let announcer: SpeechAnnouncer
    let settings: AppSettings
    let sessionStats = SessionStatsTracker()
    /// Non-nil while a guided Mission Logs procedure is running.
    private(set) var missionEngine: MissionEngine?
    var missionLogsActive: Bool { missionEngine != nil }

    @ObservationIgnored private let detector: ObjectDetector
    @ObservationIgnored private let wearablesInterface: WearablesInterface
    @ObservationIgnored private let stabilizer = DetectionStabilizer()

    // Output state
    private(set) var detections: [Detection] = []
    private(set) var summary: [ClassCount] = []
    private(set) var detectorStatus: DetectorStatus = .notLoaded
    private(set) var fps: Double = 0
    private(set) var isRunning = false
    /// True while the camera stream is being torn down + rebuilt to apply new settings.
    private(set) var isReconfiguring = false

    // User-controllable settings
    /// Speak a periodic leaderboard recap to the glasses speakers (the "Glasses Recap" toggle).
    var recapEnabled = true
    var audioEnabled = true {
        didSet { announcer.setEnabled(audioEnabled) }
    }

    // Internals
    @ObservationIgnored private var isDetecting = false
    @ObservationIgnored private var isRestarting = false
    @ObservationIgnored private var reconfigPending = false
    @ObservationIgnored private var sessionTimerTask: Task<Void, Never>?
    @ObservationIgnored private var lastSpokenRecapAt: TimeInterval = 0
    @ObservationIgnored private var frameTimestamps: [TimeInterval] = []

    init(wearablesInterface: WearablesInterface) {
        self.wearablesInterface = wearablesInterface
        wearables = WearablesManager(wearables: wearablesInterface)
        camera = GlassesCameraService(wearables: wearablesInterface)
        motion = MotionService()
        announcer = SpeechAnnouncer()
        detector = ObjectDetector()
        settings = AppSettings()

        // Seed the pipeline with the persisted settings.
        camera.resolution = settings.resolution.streamingResolution
        camera.frameRate = UInt(settings.frameRate)
        stabilizer.dwellSeconds = settings.dwellSeconds
        announcer.repeatInterval = settings.reannounceSeconds

        // React to settings changes coming from the settings sheets.
        settings.cameraConfigChanged = { [weak self] in self?.applyCameraConfig() }
        settings.confidenceChanged = { [weak self] value in
            guard let self else { return }
            Task { await self.detector.setConfidenceThreshold(value) }
        }
        settings.dwellChanged = { [weak self] value in self?.stabilizer.dwellSeconds = value }
        settings.reannounceChanged = { [weak self] value in self?.announcer.repeatInterval = value }
        settings.modelChanged = { [weak self] in self?.handleModelChange() }

        camera.onFrame = { [weak self] image in
            await self?.handleFrame(image)
        }
    }

    /// Live frame for the phone overlay (tracks the camera service).
    var currentFrame: UIImage? { camera.currentFrame }

    var statusText: String {
        if isReconfiguring { return "Applying camera settings…" }
        switch camera.status {
        case .idle: return "Idle"
        case .connecting: return "Connecting to glasses…"
        case .waitingForDevice: return "Waiting for camera…"
        case .streaming: return "Streaming"
        case .stopped: return "Stopped"
        case .error(let message): return message
        }
    }

    /// Load the Core ML model up front so the UI can report its status.
    func loadModel() async {
        let selected = settings.selectedModel
        // Fall back to a bundled model if the selected one hasn't been added yet.
        let resource = selected.isAvailable
            ? selected.resourceName
            : (DetectionModelOption.firstAvailable?.resourceName ?? selected.resourceName)
        detectorStatus = await detector.setModel(resource)
        await detector.setConfidenceThreshold(Float(settings.confidence))
    }

    /// Reloads the detector when the selected model changes. The class vocabulary differs
    /// between models, so per-session detection state is reset; detection keeps running.
    private func handleModelChange() {
        Task {
            await loadModel()
            stabilizer.reset()
            if isRunning { sessionStats.start() } else { sessionStats.reset() }
        }
    }

    /// Requests glasses camera permission (prompt appears in Meta AI). Returns whether granted.
    func requestCameraPermission() async -> Bool {
        do {
            var status = try await wearablesInterface.checkPermissionStatus(.camera)
            if status != .granted { status = try await wearablesInterface.requestPermission(.camera) }
            return status == .granted
        } catch {
            return false
        }
    }

    /// Onboarding connectivity check: registration + camera permission + a real device
    /// session (Bluetooth control link), without starting the video stream. nil = success.
    func runCommCheck() async -> String? {
        guard wearables.isRegistered else { return "Not connected to Meta AI" }
        guard await requestCameraPermission() else { return "Camera permission not granted" }
        return await camera.verifyConnection()
    }

    func start() async {
        guard !isRunning else { return }
        await loadModel()
        motion.start()
        await camera.start()
        isRunning = true
        sessionStats.start()
        startSessionTimer()
        maybeSpeakLeaderboard()
    }

    /// Drives the live session timer at 1 Hz (so it advances even if frames stall) and fires the
    /// spoken recap on the same cadence.
    private func startSessionTimer() {
        sessionTimerTask?.cancel()
        sessionTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.isRunning else { break }
                self.sessionStats.tick()
                self.maybeSpeakLeaderboard()
            }
        }
    }

    func stop() async {
        guard isRunning else { return }
        isRunning = false
        sessionTimerTask?.cancel()
        sessionTimerTask = nil
        await camera.stop()
        motion.stop()
        announcer.stop()
        stabilizer.reset()
        detections = []
        summary = []
        fps = 0
    }

    func toggleRunning() async {
        if isRunning { await stop() } else { await start() }
    }

    // MARK: - Mission Logs

    /// Begins a guided procedure: builds the engine (with speech listening if granted), ensures
    /// detection is running, and starts listening. The model is whatever the user selected.
    func startMissionLogs(_ mission: Mission, speechEnabled: Bool) async {
        let listener: SpeechListener? = speechEnabled ? SpeechListener() : nil
        let targetConfidence = settings.missionConfidence
        missionEngine = MissionEngine(
            mission: mission, announcer: announcer, speech: listener,
            strictness: settings.missionStrictness, targetConfidence: targetConfidence
        )
        if !isRunning { await start() }
        // Per-mission target-detection overrides (start()/loadModel set the global values first).
        // 0 = use the JSON's per-trigger confidence / the global Detection-settings dwell.
        stabilizer.dwellSeconds = settings.missionDwellSeconds > 0 ? settings.missionDwellSeconds : settings.dwellSeconds
        if targetConfidence > 0 { await detector.setConfidenceThreshold(Float(targetConfidence)) }
        missionEngine?.startListening()
    }

    func stopMissionLogs() {
        missionEngine?.stop()
        missionEngine = nil
        // Restore the global detection settings the mission may have overridden.
        stabilizer.dwellSeconds = settings.dwellSeconds
        let confidence = Float(settings.confidence)
        Task { await detector.setConfidenceThreshold(confidence) }
    }

    // MARK: - Live camera reconfiguration

    /// Pushes the current camera settings to the service and, if a stream is live, restarts
    /// it so the new resolution / frame rate take effect immediately. When not running, the
    /// values are simply stored and used the next time `start()` is called.
    private func applyCameraConfig() {
        camera.resolution = settings.resolution.streamingResolution
        camera.frameRate = UInt(settings.frameRate)
        Task { await restartStreamIfRunning() }
    }

    /// Restarts the live stream, coalescing rapid setting changes so overlapping restarts
    /// don't race: changes that arrive mid-restart are applied in one extra pass at the end.
    private func restartStreamIfRunning() async {
        guard isRunning else { return }
        if isRestarting { reconfigPending = true; return }
        isRestarting = true
        isReconfiguring = true
        repeat {
            reconfigPending = false
            stabilizer.reset()
            await camera.restart()
        } while reconfigPending && isRunning
        isReconfiguring = false
        isRestarting = false
    }

    // MARK: - Frame pipeline

    private func handleFrame(_ image: UIImage) async {
        recordFPS()
        guard !isDetecting, let cgImage = image.cgImage else { return }
        isDetecting = true
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let results = await detector.detect(cgImage, orientation: orientation)
        apply(results, image: image)
        isDetecting = false
    }

    private func apply(_ results: [Detection], image: UIImage) {
        // Gate detections through the dwell-time stabilizer: only labels that have persisted
        // long enough are drawn, listed, and announced.
        let now = Date().timeIntervalSinceReferenceDate
        let confirmed = stabilizer.confirmedLabels(in: results, now: now)
        let visible = results.filter { confirmed.contains($0.label) }
        sessionStats.recordFrame(labels: Set(visible.map(\.label)))
        detections = visible
        summary = DetectionAggregator.summarize(visible)
        missionEngine?.ingest(visible, frame: image)
        // During a mission the announcer is reserved for cue audio, so skip the object recap.
        if audioEnabled, missionEngine == nil { announcer.announce(summary) }
    }

    // MARK: - Spoken recap

    /// Speaks a periodic leaderboard recap to the glasses' Bluetooth speakers — each top object
    /// with its time on screen + frame count, plus the mission timer. Gated on the "Glasses
    /// Recap" toggle; cadence is the user's recap interval.
    private func maybeSpeakLeaderboard() {
        guard recapEnabled, missionEngine == nil else { return }
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastSpokenRecapAt >= settings.recapIntervalSeconds else { return }
        let top = sessionStats.leaderboard.prefix(3)
        guard !top.isEmpty else { return }
        lastSpokenRecapAt = now
        let parts = top.map { stat in
            "\(stat.label), \(SessionStatsTracker.spokenDuration(sessionStats.detectedTime(stat))), \(stat.frames) frames"
        }
        let phrase = "Mission time \(SessionStatsTracker.spokenDuration(sessionStats.elapsed)). "
            + "Most seen: " + parts.joined(separator: "; ")
        announcer.speakNow(phrase)
    }

    private func recordFPS() {
        let now = Date().timeIntervalSinceReferenceDate
        frameTimestamps.append(now)
        frameTimestamps.removeAll { now - $0 > 1.0 }
        fps = Double(frameTimestamps.count)
    }
}
