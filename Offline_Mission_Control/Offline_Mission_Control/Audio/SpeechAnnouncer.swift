//
//  SpeechAnnouncer.swift
//  Offline_Mission_Control
//
//  Speaks detected objects via on-device text-to-speech. When the glasses are connected
//  they act as a standard Bluetooth audio output, so system/app audio routes to them
//  automatically. Playback is app-controllable (enable / pause / resume / stop).
//
//  Announcements are throttled so the same label isn't repeated constantly: a label is
//  re-announced only after `repeatInterval` seconds, or immediately when it newly appears.
//

import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class SpeechAnnouncer {
    /// Master on/off for spoken output.
    var isEnabled = true
    private(set) var isSpeaking = false
    private(set) var isPaused = false

    /// Don't repeat the same label more often than this.
    var repeatInterval: TimeInterval = 4.0
    /// Speech rate (AVSpeechUtterance scale).
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var lastSpokenAt: [String: TimeInterval] = [:]
    @ObservationIgnored private var audioConfigured = false

    func configureAudioSessionIfNeeded() {
        guard !audioConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.duckOthers, .allowBluetoothA2DP]
        )
        try? session.setActive(true)
        audioConfigured = true
    }

    /// Announce the most prominent new objects in this frame's summary.
    func announce(_ summary: [ClassCount]) {
        guard isEnabled, !summary.isEmpty else { return }
        configureAudioSessionIfNeeded()

        let now = Date().timeIntervalSinceReferenceDate
        // Speak at most the top 2 classes that are due to be (re)announced.
        let due = summary.prefix(3).filter { now - (lastSpokenAt[$0.label] ?? 0) >= repeatInterval }
        guard let phrase = phrase(for: Array(due.prefix(2))) else { return }
        for c in due { lastSpokenAt[c.label] = now }
        speak(phrase)
    }

    func speakNow(_ text: String) {
        configureAudioSessionIfNeeded()
        speak(text)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled { stop() }
    }

    func pause() {
        guard synthesizer.isSpeaking, !synthesizer.isPaused else { return }
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
    }

    func resume() {
        guard synthesizer.isPaused else { return }
        synthesizer.continueSpeaking()
        isPaused = false
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
        lastSpokenAt.removeAll()
    }

    // MARK: - Private

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        synthesizer.speak(utterance)
        isSpeaking = true
        isPaused = false
    }

    private func phrase(for classes: [ClassCount]) -> String? {
        guard !classes.isEmpty else { return nil }
        return classes.map { c in
            c.count > 1 ? "\(c.count) \(pluralize(c.label))" : "\(article(c.label)) \(c.label)"
        }.joined(separator: ", ")
    }

    private func article(_ word: String) -> String {
        "aeiou".contains(word.lowercased().first ?? " ") ? "an" : "a"
    }

    private func pluralize(_ word: String) -> String {
        if word.hasSuffix("s") || word.hasSuffix("x") { return word + "es" }
        if word.hasSuffix("y") { return String(word.dropLast()) + "ies" }
        return word + "s"
    }
}
