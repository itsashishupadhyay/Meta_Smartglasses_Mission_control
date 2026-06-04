//
//  GlassesCameraService.swift
//  Offline_Mission_Control
//
//  Owns a DeviceSession + camera Stream on the glasses and delivers live frames.
//  Distilled from the CameraAccess sample (StreamSessionViewModel + DeviceSessionManager).
//  Frames are delivered to `onFrame` on the MainActor; the orchestrator runs detection.
//

import MWDATCamera
import MWDATCore
import Observation
import SwiftUI

@Observable
@MainActor
final class GlassesCameraService {
    enum Status: Equatable {
        case idle
        case connecting
        case waitingForDevice
        case streaming
        case stopped
        case error(String)
    }

    private(set) var status: Status = .idle
    private(set) var currentFrame: UIImage?
    private(set) var hasReceivedFirstFrame = false

    /// Stream quality.
    var resolution: StreamingResolution = .medium
    var frameRate: UInt = 15

    /// Async, MainActor-isolated frame sink set by the orchestrator.
    var onFrame: ((UIImage) async -> Void)?

    /// True once the auto-selector has discovered an eligible (connected) device.
    private(set) var hasActiveDevice = false

    @ObservationIgnored private let wearables: WearablesInterface
    @ObservationIgnored private let deviceSelector: AutoDeviceSelector
    @ObservationIgnored private var deviceMonitorTask: Task<Void, Never>?
    @ObservationIgnored private var deviceSession: DeviceSession?
    @ObservationIgnored private var stream: MWDATCamera.Stream?
    @ObservationIgnored private var stateToken: AnyListenerToken?
    @ObservationIgnored private var frameToken: AnyListenerToken?
    @ObservationIgnored private var errorToken: AnyListenerToken?
    @ObservationIgnored private var frameCount = 0
    @ObservationIgnored private var sessionErrorTask: Task<Void, Never>?

    init(wearables: WearablesInterface) {
        self.wearables = wearables
        self.deviceSelector = AutoDeviceSelector(wearables: wearables)
        // Keep the selector alive and monitoring from launch so it has an eligible device
        // ready by the time the user starts streaming (avoids noEligibleDevice).
        deviceMonitorTask = Task { [weak self] in
            guard let selector = self?.deviceSelector else { return }
            for await device in selector.activeDeviceStream() {
                self?.hasActiveDevice = (device != nil)
            }
        }
    }

    isolated deinit {
        deviceMonitorTask?.cancel()
        sessionErrorTask?.cancel()
    }

    var isStreaming: Bool { status == .streaming }

    func start() async {
        guard status != .connecting, status != .streaming else { return }
        status = .connecting

        // 1. Camera permission (granted through the Meta AI companion app).
        do {
            var permission = try await wearables.checkPermissionStatus(.camera)
            if permission != .granted {
                permission = try await wearables.requestPermission(.camera)
            }
            guard permission == .granted else {
                status = .error("Camera permission denied")
                return
            }
        } catch {
            // `error` is a typed `PermissionError` here (typed throws), so use its description.
            status = .error(error.description)
            return
        }

        print("🟦 OMC: camera permission granted")

        // 2. Create the device session. The selector may need a moment to discover the
        //    connected glasses, so retry briefly on `noEligibleDevice` rather than failing.
        let session: DeviceSession
        do {
            session = try await createSessionWithRetry()
        } catch DeviceSessionError.datAppOnTheGlassesUpdateRequired {
            status = .error("The glasses need a software update before streaming")
            return
        } catch DeviceSessionError.noEligibleDevice {
            status = .error("No eligible glasses found. Make sure they're connected and unfolded in the Meta AI app, then try again.")
            return
        } catch {
            status = .error("Failed to start session: \(error.localizedDescription)")
            return
        }
        deviceSession = session
        print("🟦 OMC: session created (devices=\(wearables.devices.count))")
        sessionErrorTask = Task { [weak self] in
            for await error in session.errorStream() {
                guard let self else { return }
                print("🟦 OMC: session ERROR = \(error)")
                self.status = .error("Session error: \(error)")
            }
        }

        // 3. Start the session and wait for `.started`.
        let states = session.stateStream()
        do {
            try session.start()
        } catch {
            status = .error("Failed to start session: \(error.localizedDescription)")
            return
        }
        if session.state != .started {
            for await state in states {
                if state == .started { break }
                if state == .stopped {
                    status = .error("Session stopped before it started")
                    return
                }
            }
        }
        guard session.state == .started else {
            status = .error("Device session is not ready")
            return
        }

        // 4. Attach the camera stream.
        let config = StreamConfiguration(videoCodec: .raw, resolution: resolution, frameRate: frameRate)
        guard let newStream = try? session.addStream(config: config) else {
            status = .error("Could not add camera stream")
            return
        }
        stream = newStream
        status = .waitingForDevice
        setupListeners(for: newStream)
        print("🟦 OMC: session started — camera stream added, starting…")
        await newStream.start()
        print("🟦 OMC: stream.start() returned (waiting for frames)")
    }

    func stop() async {
        let activeStream = stream
        stream = nil
        stateToken = nil
        frameToken = nil
        errorToken = nil
        sessionErrorTask?.cancel()
        sessionErrorTask = nil
        await activeStream?.stop()
        deviceSession?.stop()
        deviceSession = nil
        currentFrame = nil
        hasReceivedFirstFrame = false
        status = .stopped
    }

    /// Verifies the Bluetooth control link by creating + starting a device session (no video
    /// stream), then stopping it. Returns nil on success or a message. Used by onboarding.
    func verifyConnection() async -> String? {
        do {
            let session = try await createSessionWithRetry()
            let states = session.stateStream()
            try session.start()
            var started = (session.state == .started)
            if !started {
                for await state in states {
                    if state == .started { started = true; break }
                    if state == .stopped { break }
                }
            }
            session.stop()
            return started ? nil : "Couldn't establish a session with the glasses"
        } catch {
            return "Session check failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Private

    /// Waits briefly for the glasses to appear in the device list (the selector needs a
    /// moment after connect/launch), then creates the session once. Its typed error —
    /// including `noEligibleDevice` — propagates to the caller.
    ///
    /// NOTE: we intentionally do NOT `catch` the `throws(DeviceSessionError)` case inside
    /// this async loop — doing so crashes the current Swift compiler's SILGen ownership
    /// verifier. Gating on the non-throwing `wearables.devices` sidesteps that entirely.
    private func createSessionWithRetry(maxAttempts: Int = 10) async throws -> DeviceSession {
        var attempt = 0
        while wearables.devices.isEmpty, attempt < maxAttempts {
            attempt += 1
            try? await Task.sleep(for: .milliseconds(300))
        }
        return try wearables.createSession(deviceSelector: deviceSelector)
    }

    private func setupListeners(for stream: MWDATCamera.Stream) {
        stateToken = stream.statePublisher.listen { [weak self] state in
            guard let self else { return }
            Task { @MainActor in self.handleState(state) }
        }
        frameToken = stream.videoFramePublisher.listen { [weak self] frame in
            guard let self else { return }
            Task { @MainActor in await self.handleFrame(frame) }
        }
        errorToken = stream.errorPublisher.listen { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                print("🟦 OMC: stream ERROR = \(error)")
                self.status = .error("Stream error: \(error)")
            }
        }
    }

    private func handleState(_ state: StreamState) {
        print("🟦 OMC: stream state = \(state)")
        switch state {
        case .streaming:
            status = .streaming
        case .stopped:
            status = .stopped
            currentFrame = nil
        case .waitingForDevice, .starting, .stopping, .paused:
            if status != .streaming { status = .waitingForDevice }
        }
    }

    private func handleFrame(_ frame: VideoFrame) async {
        frameCount += 1
        guard let image = frame.makeUIImage() else {
            if frameCount % 30 == 1 { print("🟦 OMC: frame #\(frameCount) — makeUIImage() returned NIL") }
            return
        }
        if frameCount == 1 || frameCount % 30 == 0 {
            print("🟦 OMC: frame #\(frameCount) \(Int(image.size.width))x\(Int(image.size.height))")
        }
        currentFrame = image
        hasReceivedFirstFrame = true
        await onFrame?(image)
    }
}
