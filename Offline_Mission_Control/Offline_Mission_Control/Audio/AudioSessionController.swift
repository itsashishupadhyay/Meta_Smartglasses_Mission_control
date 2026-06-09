//
//  AudioSessionController.swift
//  Offline_Mission_Control
//
//  Single owner of the app's AVAudioSession so TTS output and speech-recognition input never set
//  conflicting categories (last-writer-wins on AVAudioSession). Default = `.playback` (TTS to the
//  glasses over A2DP). When Mission Logs needs the mic, it switches to `.playAndRecord` — keeping
//  A2DP output to the glasses while capturing from the iPhone's built-in mic.
//
//  NOTE: we intentionally do NOT request `.allowBluetooth` (HFP) — that would drag TTS onto a
//  narrowband SCO link and collapse the high-quality A2DP cue audio.
//

import AVFoundation

@MainActor
final class AudioSessionController {
    static let shared = AudioSessionController()
    private init() {}

    private var recordingNeeded = false
    private var configured = false

    /// Toggle record capability (Mission Logs speech listening). Reconfigures immediately.
    func setRecordingNeeded(_ needed: Bool) {
        guard needed != recordingNeeded else { return }
        recordingNeeded = needed
        configured = false
        apply()
    }

    /// Ensure the session is configured + active (call before speaking or starting the engine).
    func ensureActive() {
        guard !configured else { return }
        apply()
    }

    private func apply() {
        let session = AVAudioSession.sharedInstance()
        do {
            if recordingNeeded {
                try session.setCategory(
                    .playAndRecord,
                    mode: .spokenAudio,
                    options: [.allowBluetoothA2DP, .defaultToSpeaker, .duckOthers]
                )
                if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                    try? session.setPreferredInput(builtIn)
                }
            } else {
                try session.setCategory(
                    .playback,
                    mode: .spokenAudio,
                    options: [.duckOthers, .allowBluetoothA2DP]
                )
            }
            try session.setActive(true)
            configured = true
        } catch {
            // Best-effort: audio routing is non-fatal to the rest of the app.
        }
    }
}
