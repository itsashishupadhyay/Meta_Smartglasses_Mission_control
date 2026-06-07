//
//  MissionControlViewModel.swift
//  Offline_Mission_Control
//
//  Orchestrates the full pipeline:
//    glasses camera frame -> Core ML detector (off-main) -> phone overlay + HUD card + speech.
//  The same pipeline serves BOTH glasses types; display-only behaviour (the HUD card) is gated
//  on a display-capable device being present.
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
    let display: GlassesDisplayService
    let motion: MotionService
    let announcer: SpeechAnnouncer
    let settings: AppSettings
    let sessionStats = SessionStatsTracker()

    @ObservationIgnored private let detector: ObjectDetector
    @ObservationIgnored private let wearablesInterface: WearablesInterface
    @ObservationIgnored private let stabilizer = DetectionStabilizer()

    // Output state
    private(set) var detections: [Detection] = []
    private(set) var summary: [ClassCount] = []
    private(set) var summaryLine = "No objects detected"
    private(set) var detectorStatus: DetectorStatus = .notLoaded
    private(set) var fps: Double = 0
    private(set) var isRunning = false
    /// True while the camera stream is being torn down + rebuilt to apply new settings.
    private(set) var isReconfiguring = false

    // User-controllable settings
    var hudEnabled = true
    var audioEnabled = true {
        didSet { announcer.setEnabled(audioEnabled) }
    }

    // Internals
    @ObservationIgnored private var isDetecting = false
    @ObservationIgnored private var isRestarting = false
    @ObservationIgnored private var reconfigPending = false
    @ObservationIgnored private var sessionTimerTask: Task<Void, Never>?
    @ObservationIgnored private var lastHUDLine = ""
    @ObservationIgnored private var lastHUDSentAt: TimeInterval = 0
    @ObservationIgnored private var frameTimestamps: [TimeInterval] = []

    init(wearablesInterface: WearablesInterface) {
        self.wearablesInterface = wearablesInterface
        wearables = WearablesManager(wearables: wearablesInterface)
        camera = GlassesCameraService(wearables: wearablesInterface)
        display = GlassesDisplayService(wearables: wearablesInterface)
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

        camera.onFrame = { [weak self] image in
            await self?.handleFrame(image)
        }
    }

    /// Live frame for the phone overlay (tracks the camera service).
    var currentFrame: UIImage? { camera.currentFrame }

    var canUseHUD: Bool { wearables.hasDisplayCapableDevice }

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
        detectorStatus = await detector.prepare()
        await detector.setConfidenceThreshold(Float(settings.confidence))
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
    }

    /// Drives the live session timer at 1 Hz so it keeps advancing even if frames stall.
    private func startSessionTimer() {
        sessionTimerTask?.cancel()
        sessionTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.isRunning else { break }
                self.sessionStats.tick()
            }
        }
    }

    func stop() async {
        guard isRunning else { return }
        isRunning = false
        await camera.stop()
        motion.stop()
        announcer.stop()
        await display.detach()
        stabilizer.reset()
        sessionTimerTask?.cancel()
        sessionTimerTask = nil
        detections = []
        summary = []
        summaryLine = "No objects detected"
        lastHUDLine = ""
        fps = 0
    }

    func toggleRunning() async {
        if isRunning { await stop() } else { await start() }
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
        apply(results)
        isDetecting = false
    }

    private func apply(_ results: [Detection]) {
        // Gate detections through the dwell-time stabilizer: only labels that have persisted
        // long enough are drawn, listed, announced, and sent to the HUD.
        let now = Date().timeIntervalSinceReferenceDate
        let confirmed = stabilizer.confirmedLabels(in: results, now: now)
        let visible = results.filter { confirmed.contains($0.label) }
        sessionStats.recordFrame(labels: Set(visible.map(\.label)))
        detections = visible
        summary = DetectionAggregator.summarize(visible)
        summaryLine = DetectionAggregator.summaryLine(summary)
        if audioEnabled { announcer.announce(summary) }
        if hudEnabled { maybeSendHUD() }
    }

    private func maybeSendHUD() {
        guard wearables.hasDisplayCapableDevice else { return }
        let now = Date().timeIntervalSinceReferenceDate
        guard summaryLine != lastHUDLine, now - lastHUDSentAt > 0.5 else { return }
        lastHUDLine = summaryLine
        lastHUDSentAt = now
        let card = DetectionHUD.card(summaryLine: summaryLine, objectCount: detections.count)
        Task { await display.send(card) }
    }

    private func recordFPS() {
        let now = Date().timeIntervalSinceReferenceDate
        frameTimestamps.append(now)
        frameTimestamps.removeAll { now - $0 > 1.0 }
        fps = Double(frameTimestamps.count)
    }
}
