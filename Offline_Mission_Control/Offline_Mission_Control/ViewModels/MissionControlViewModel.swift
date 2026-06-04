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

    @ObservationIgnored private let detector: ObjectDetector
    @ObservationIgnored private let wearablesInterface: WearablesInterface

    // Output state
    private(set) var detections: [Detection] = []
    private(set) var summary: [ClassCount] = []
    private(set) var summaryLine = "No objects detected"
    private(set) var detectorStatus: DetectorStatus = .notLoaded
    private(set) var fps: Double = 0
    private(set) var isRunning = false

    // User-controllable settings
    var hudEnabled = true
    var audioEnabled = true {
        didSet { announcer.setEnabled(audioEnabled) }
    }
    var confidenceThreshold: Float = 0.35 {
        didSet {
            let value = confidenceThreshold
            Task { await detector.setConfidenceThreshold(value) }
        }
    }

    // Internals
    @ObservationIgnored private var isDetecting = false
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
        camera.onFrame = { [weak self] image in
            await self?.handleFrame(image)
        }
    }

    /// Live frame for the phone overlay (tracks the camera service).
    var currentFrame: UIImage? { camera.currentFrame }

    var canUseHUD: Bool { wearables.hasDisplayCapableDevice }

    var statusText: String {
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
        await detector.setConfidenceThreshold(confidenceThreshold)
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
    }

    func stop() async {
        guard isRunning else { return }
        isRunning = false
        await camera.stop()
        motion.stop()
        announcer.stop()
        await display.detach()
        detections = []
        summary = []
        summaryLine = "No objects detected"
        lastHUDLine = ""
        fps = 0
    }

    func toggleRunning() async {
        if isRunning { await stop() } else { await start() }
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
        detections = results
        summary = DetectionAggregator.summarize(results)
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
