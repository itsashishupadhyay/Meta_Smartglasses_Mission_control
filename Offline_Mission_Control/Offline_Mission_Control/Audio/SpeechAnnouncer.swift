//
//  SpeechAnnouncer.swift
//  Offline_Mission_Control
//
//  Speaks detected objects (and Mission Logs cues) via on-device text-to-speech. When the glasses
//  are connected they're a standard Bluetooth audio output, so speech routes to them automatically.
//  Playback is app-controllable (enable / pause / resume / stop).
//
//  Announcements are throttled so the same label isn't repeated constantly. The audio session is
//  owned by `AudioSessionController` (shared with speech recognition). The synthesizer's start/finish
//  is surfaced via `onWillSpeak` / `onDidFinishSpeaking` so Mission Logs can run the mic half-duplex.
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

    /// Fired when the synthesizer starts / finishes (or cancels) speaking — used for half-duplex
    /// coordination with the speech recognizer.
    @ObservationIgnored var onWillSpeak: (() -> Void)?
    @ObservationIgnored var onDidFinishSpeaking: (() -> Void)?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let delegateProxy = SynthesizerDelegateProxy()
    @ObservationIgnored private var lastSpokenAt: [String: TimeInterval] = [:]

    init() {
        synthesizer.delegate = delegateProxy
        delegateProxy.onStart = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isSpeaking = true
                self?.onWillSpeak?()
            }
        }
        delegateProxy.onFinish = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isSpeaking = false
                self?.onDidFinishSpeaking?()
            }
        }
    }

    /// Announce the most prominent new objects in this frame's summary.
    func announce(_ summary: [ClassCount]) {
        guard isEnabled, !summary.isEmpty else { return }
        let now = Date().timeIntervalSinceReferenceDate
        let due = summary.prefix(3).filter { now - (lastSpokenAt[$0.label] ?? 0) >= repeatInterval }
        guard let phrase = phrase(for: Array(due.prefix(2))) else { return }
        for c in due { lastSpokenAt[c.label] = now }
        speak(phrase)
    }

    /// Speak text immediately, interrupting any in-progress utterance (used for mission cues).
    func speakNow(_ text: String) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .word) }
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
        AudioSessionController.shared.ensureActive()
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

/// NSObject delegate shim so `SpeechAnnouncer` (a plain @Observable class) doesn't have to be an
/// NSObject subclass. Callbacks arrive on the main thread; the closures hop to the MainActor.
private final class SynthesizerDelegateProxy: NSObject, AVSpeechSynthesizerDelegate {
    var onStart: (@Sendable () -> Void)?
    var onFinish: (@Sendable () -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        onStart?()
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish?()
    }
}
