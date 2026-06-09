//
//  SpeechListener.swift
//  Offline_Mission_Control
//
//  On-device speech recognition (SFSpeechRecognizer + AVAudioEngine) used by Mission Logs to hear
//  the crew's spoken `expected_indication` call-outs. Runs a rolling recognizer (legs recycle on
//  finish/error/timeout so listening is continuous past the per-task limit) and supports
//  suspend/resume so the glasses TTS cue isn't transcribed as a confirmation (half-duplex).
//

import AVFoundation
import Observation
import Speech

@Observable
@MainActor
final class SpeechListener {
    private(set) var isAvailable: Bool
    private(set) var isAuthorized = false
    private(set) var isListening = false
    private(set) var lastTranscript = ""

    /// Latest partial/final transcript text (the mission engine fuzzy-matches it).
    @ObservationIgnored var onTranscript: ((String) -> Void)?

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var wantRunning = false
    @ObservationIgnored private var suspended = false

    init() {
        isAvailable = (recognizer?.isAvailable ?? false)
    }

    /// Requests mic + speech-recognition permission. Returns true only if BOTH are granted.
    static func requestAuthorization() async -> Bool {
        let mic = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
        guard mic else { return false }
        let speech = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        return speech
    }

    func start() {
        guard let recognizer, recognizer.isAvailable,
              SFSpeechRecognizer.authorizationStatus() == .authorized else {
            isAuthorized = false
            return
        }
        isAuthorized = true
        wantRunning = true
        suspended = false
        AudioSessionController.shared.setRecordingNeeded(true)
        beginLeg()
        isListening = true
    }

    func stop() {
        wantRunning = false
        suspended = false
        isListening = false
        endLeg()
        if engine.isRunning { engine.stop() }
        AudioSessionController.shared.setRecordingNeeded(false)
    }

    /// Half-duplex: pause feeding the recognizer while the glasses TTS cue plays.
    func suspend() {
        guard wantRunning, !suspended else { return }
        suspended = true
        isListening = false
        endLeg()
    }

    func resume() {
        guard wantRunning, suspended else { return }
        suspended = false
        beginLeg()
        isListening = true
    }

    /// Drop the current recognition leg and start fresh, clearing the accumulated transcript so a
    /// just-acted-on phrase (e.g. a cheat code) doesn't keep re-firing on subsequent partials.
    func resetRecognition() {
        guard wantRunning, !suspended else { return }
        lastTranscript = ""
        Task { @MainActor [weak self] in
            guard let self, self.wantRunning, !self.suspended else { return }
            self.beginLeg()
        }
    }

    // MARK: - Recognition legs

    private func beginLeg() {
        guard wantRunning, !suspended, let recognizer else { return }
        endLeg()

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .search
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req

        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        // The tap runs on a realtime audio thread; capture the request directly (append is
        // thread-safe) rather than touching MainActor state from the closure.
        nonisolated(unsafe) let capturedReq = req
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            capturedReq.append(buffer)
        }
        if !engine.isRunning {
            AudioSessionController.shared.ensureActive()
            engine.prepare()
            try? engine.start()
        }

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.lastTranscript = text
                    self.onTranscript?(text)
                    if result.isFinal { self.recycleLeg() }
                } else if error != nil {
                    self.recycleLeg()
                }
            }
        }
    }

    private func endLeg() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if engine.isRunning { engine.inputNode.removeTap(onBus: 0) }
    }

    private func recycleLeg() {
        guard wantRunning, !suspended else { return }
        endLeg()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, self.wantRunning, !self.suspended, self.task == nil else { return }
            self.beginLeg()
        }
    }
}
