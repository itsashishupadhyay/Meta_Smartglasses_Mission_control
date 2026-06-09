//
//  MissionEngine.swift
//  Offline_Mission_Control
//
//  Runs a mission-log state machine on top of the live detection pipeline:
//   • shows the active state's cue card (swipeable),
//   • when the state's object_trigger COCO class is detected → speaks `message_log` + starts an
//     inverse countdown from `approx_time_min`,
//   • advances on a fuzzy match of `expected_indication` (heard via SpeechListener) OR a manual
//     confirm / a user swipe to another card,
//   • tracks "N of total" nominal task progress.
//
//  It is FED detections by the orchestrator; it does not own the camera or detector.
//

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class MissionEngine {
    let mission: Mission

    /// The swipeable cue cards (the nominal line; contingency / get-ahead states are spliced in
    /// when entered).
    private(set) var orderedStates: [MissionState]
    /// Two-way bound to the cue-card pager. The VISIBLE card is the active state — a user swipe
    /// retargets detection + cue + matcher to it.
    var visibleIndex: Int = 0 {
        didSet {
            guard !settingActiveProgrammatically,
                  visibleIndex != oldValue,
                  orderedStates.indices.contains(visibleIndex) else { return }
            retarget(to: orderedStates[visibleIndex].stateID)
        }
    }

    private(set) var activeStateID: String
    private(set) var completedStateIDs: Set<String> = []
    /// True once the active state's object_trigger has fired (cue spoken, countdown running).
    private(set) var isActivated = false
    private(set) var remainingSeconds = 0
    private(set) var countdownTotal = 0
    private(set) var lastHeard = ""
    private(set) var isComplete = false
    /// Per-step report entries, accumulated as steps are confirmed.
    private(set) var stepRecords: [MissionStepRecord] = []

    @ObservationIgnored let announcer: SpeechAnnouncer
    @ObservationIgnored let speech: SpeechListener?
    @ObservationIgnored private let strictness: MissionMatchStrictness
    /// Target confidence override (0 = use each trigger's JSON `confidence_min`).
    @ObservationIgnored private let targetConfidence: Double
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var settingActiveProgrammatically = false
    /// Debounce so repeated partial transcripts of one utterance don't fire an action many times.
    @ObservationIgnored private var lastVoiceActionAt: TimeInterval = 0

    // Per-active-step capture (for the report).
    @ObservationIgnored private var activeStepStartedAt = Date()
    @ObservationIgnored private var targetSeenAccum: TimeInterval = 0
    @ObservationIgnored private var targetPresentSince: Date?
    @ObservationIgnored private var pendingSnapshot: UIImage?

    init(mission: Mission, announcer: SpeechAnnouncer, speech: SpeechListener?, strictness: MissionMatchStrictness = .balanced, targetConfidence: Double = 0) {
        self.mission = mission
        self.announcer = announcer
        self.speech = speech
        self.strictness = strictness
        self.targetConfidence = targetConfidence

        let line = mission.nominalLine
        orderedStates = line
        activeStateID = mission.startState
        visibleIndex = line.firstIndex { $0.stateID == mission.startState } ?? 0

        speech?.onTranscript = { [weak self] text in self?.heard(text) }
        announcer.onWillSpeak = { [weak self] in self?.speech?.suspend() }
        announcer.onDidFinishSpeaking = { [weak self] in
            // Trailing guard for the A2DP speaker tail before re-opening the mic.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                self?.speech?.resume()
            }
        }
    }

    // MARK: - Derived

    var activeState: MissionState {
        orderedStates.first { $0.stateID == activeStateID }
            ?? orderedStates[min(visibleIndex, orderedStates.count - 1)]
    }
    var progressTotal: Int { mission.nominalStepCount }
    var progressDone: Int {
        orderedStates.filter {
            completedStateIDs.contains($0.stateID) && ($0.type == .task || $0.type == .gate)
        }.count
    }
    /// COCO labels (lowercased) the active card highlights with a thicker box.
    var highlightedLabels: Set<String> { Set(activeState.objectTrigger.map { $0.cocoClass.lowercased() }) }

    // MARK: - Lifecycle

    func startListening() { speech?.start() }

    func stop() {
        countdownTask?.cancel()
        countdownTask = nil
        speech?.stop()
        announcer.onWillSpeak = nil
        announcer.onDidFinishSpeaking = nil
    }

    // MARK: - Detection input (fed by the orchestrator each processed frame)

    func ingest(_ detections: [Detection], frame: UIImage?) {
        guard !isComplete else { return }
        let triggers = activeState.objectTrigger
        let present = !triggers.isEmpty && detections.contains { d in
            triggers.contains { t in
                d.label.caseInsensitiveCompare(t.cocoClass) == .orderedSame
                    && d.confidence >= effectiveConfidence(for: t)
            }
        }

        // Track how long the target is in view + grab a snapshot while it's present (for the report).
        let now = Date()
        if present {
            if targetPresentSince == nil { targetPresentSince = now }
            if let frame { pendingSnapshot = frame }
        } else if let since = targetPresentSince {
            targetSeenAccum += now.timeIntervalSince(since)
            targetPresentSince = nil
        }

        if !isActivated, present { activate() }
    }

    private func activate() {
        isActivated = true
        announcer.speakNow(activeState.messageLog)   // half-duplex begins via the announcer delegate
        startCountdown(minutes: activeState.approxTimeMin)
    }

    private func startCountdown(minutes: Int) {
        countdownTotal = max(0, minutes) * 60
        remainingSeconds = countdownTotal
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.remainingSeconds > 0 else { break }
                try? await Task.sleep(for: .seconds(1))
                self.remainingSeconds -= 1
            }
            // Timeout is advisory — it never auto-advances the procedure.
        }
    }

    // MARK: - Speech → fuzzy advance

    private func heard(_ text: String) {
        lastHeard = text
        guard !isComplete else { return }
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastVoiceActionAt > 2.0 else { return }   // debounce partial-transcript repeats
        let clean = normalized(text)

        // Force-advance on the override phrase, regardless of the step's expected indication.
        if clean.contains("confirmed override") {
            lastVoiceActionAt = now
            speech?.resetRecognition()   // clear the leg so the phrase doesn't re-fire (multi-advance)
            advance(to: activeState.onConfirm, reason: .override)
            return
        }
        // Re-read the current cue on request (the TTS suspend/resume cycle resets the leg).
        if clean.contains("replay") {
            lastVoiceActionAt = now
            announcer.speakNow(activeState.messageLog)
            return
        }
        // Normal advance: after the object has activated the step, on a fuzzy indication match.
        guard isActivated, let expected = activeState.expectedIndication else { return }
        if FuzzyMatcher.matches(heard: text, expected: expected, threshold: strictness.threshold, minHits: strictness.minHits) {
            lastVoiceActionAt = now
            speech?.resetRecognition()
            advance(to: activeState.onConfirm, reason: .voice(text))
        }
    }

    private func normalized(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Transitions

    func confirmActive() { advance(to: activeState.onConfirm, reason: .manual) }
    func anomalyActive() { advance(to: activeState.onAnomaly ?? activeState.onConfirm, reason: .manual) }

    /// Un-confirm a completed step and make it the active card again (the "re-enable" button).
    /// This also decrements the progress count and drops its report entry.
    func reEnable(_ id: String) {
        completedStateIDs.remove(id)
        stepRecords.removeAll { $0.stateID == id }
        isComplete = false
        setActive(id)
    }

    private func advance(to id: String?, reason: StepConfirmation) {
        recordCurrentStep(reason: reason)
        completedStateIDs.insert(activeStateID)
        clearActivation()
        guard let id, let next = mission.state(id: id), next.type != .terminal else {
            completeProcedure()
            return
        }
        // Splice an off-nominal state (contingency / get-ahead) in right after the current card.
        if !orderedStates.contains(where: { $0.stateID == next.stateID }) {
            let insertAt = min(visibleIndex + 1, orderedStates.count)
            orderedStates.insert(next, at: insertAt)
        }
        setActive(next.stateID)
    }

    private func recordCurrentStep(reason: StepConfirmation) {
        let state = activeState
        let record = MissionStepRecord(
            stateID: state.stateID,
            taskName: state.taskName,
            section: state.section,
            confirmedAt: Date(),
            duration: Date().timeIntervalSince(activeStepStartedAt),
            targetSeenSeconds: currentTargetSeenSeconds(),
            confirmation: reason,
            snapshot: pendingSnapshot
        )
        stepRecords.removeAll { $0.stateID == state.stateID }   // replace if re-confirmed
        stepRecords.append(record)
    }

    private func currentTargetSeenSeconds() -> TimeInterval {
        var total = targetSeenAccum
        if let since = targetPresentSince { total += Date().timeIntervalSince(since) }
        return total
    }

    private func effectiveConfidence(for trigger: ObjectTrigger) -> Float {
        targetConfidence > 0 ? Float(targetConfidence) : (trigger.confidenceMin ?? 0)
    }

    private func resetStepTracking() {
        activeStepStartedAt = Date()
        targetSeenAccum = 0
        targetPresentSince = nil
        pendingSnapshot = nil
    }

    /// User swiped — make the visible card the active one.
    private func retarget(to id: String) {
        activeStateID = id
        clearActivation()
        resetStepTracking()
    }

    private func setActive(_ id: String) {
        activeStateID = id
        clearActivation()
        resetStepTracking()
        if let idx = orderedStates.firstIndex(where: { $0.stateID == id }), idx != visibleIndex {
            settingActiveProgrammatically = true
            visibleIndex = idx
            settingActiveProgrammatically = false
        }
    }

    private func clearActivation() {
        isActivated = false
        remainingSeconds = 0
        countdownTotal = 0
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func completeProcedure() {
        isComplete = true
        clearActivation()
        speech?.stop()
        if let idx = orderedStates.firstIndex(where: { $0.type == .terminal }) {
            activeStateID = orderedStates[idx].stateID
            settingActiveProgrammatically = true
            visibleIndex = idx
            settingActiveProgrammatically = false
            announcer.speakNow(orderedStates[idx].messageLog)
        }
    }
}
