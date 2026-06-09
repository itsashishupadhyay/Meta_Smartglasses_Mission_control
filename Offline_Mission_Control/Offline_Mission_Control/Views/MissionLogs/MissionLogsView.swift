//
//  MissionLogsView.swift
//  Offline_Mission_Control
//
//  The live guided-procedure screen: camera with the active task's object highlighted, the
//  progress bar, swipeable cue cards (the visible card is the active state), and the
//  listening/confirm controls.
//

import SwiftUI

struct MissionLogsView: View {
    var vm: MissionControlViewModel
    var onExit: () -> Void

    @State private var showReport = false

    var body: some View {
        if let engine = vm.missionEngine {
            content(engine)
        } else {
            Color.black.ignoresSafeArea().onAppear { onExit() }
        }
    }

    private func content(_ engine: MissionEngine) -> some View {
        NavigationStack {
            VStack(spacing: 14) {
                camera(engine)
                MissionProgressBar(
                    done: engine.progressDone,
                    total: engine.progressTotal,
                    section: engine.activeState.section,
                    taskName: engine.activeState.taskName
                )
                cards(engine)
                controls(engine)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .missionBackground()
            .navigationTitle(engine.mission.procedure.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Exit") { onExit() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .onChange(of: engine.isComplete) { _, complete in
            if complete { showReport = true }
        }
        .fullScreenCover(isPresented: $showReport) {
            MissionReportView(mission: engine.mission, records: engine.stepRecords) {
                showReport = false
                onExit()
            }
        }
    }

    private func camera(_ engine: MissionEngine) -> some View {
        DetectionOverlayView(
            image: vm.currentFrame,
            detections: vm.detections,
            highlightedLabels: engine.highlightedLabels
        )
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
        )
    }

    private func cards(_ engine: MissionEngine) -> some View {
        TabView(selection: Binding(get: { engine.visibleIndex }, set: { engine.visibleIndex = $0 })) {
            ForEach(Array(engine.orderedStates.enumerated()), id: \.element.id) { index, state in
                CueCardView(
                    state: state,
                    isActivated: state.stateID == engine.activeStateID && engine.isActivated,
                    isComplete: engine.isComplete && state.type == .terminal,
                    remaining: engine.remainingSeconds,
                    total: engine.countdownTotal,
                    isConfirmed: engine.completedStateIDs.contains(state.stateID),
                    onReEnable: { engine.reEnable(state.stateID) }
                )
                .padding(.bottom, 28)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controls(_ engine: MissionEngine) -> some View {
        VStack(spacing: 12) {
            listeningRow(engine)
            HStack(spacing: 10) {
                if engine.activeState.onAnomaly != nil {
                    Button { engine.anomalyActive() } label: {
                        Label("Anomaly", systemImage: "exclamationmark.triangle.fill")
                    }
                    .buttonStyle(.missionSecondary)
                }
                Button { engine.confirmActive() } label: {
                    Label("Confirm step", systemImage: "checkmark")
                }
                .buttonStyle(.missionProminent)
                .disabled(engine.isComplete)
            }
        }
        .glassCard(padding: 12)
    }

    @ViewBuilder private func listeningRow(_ engine: MissionEngine) -> some View {
        if let speech = engine.speech {
            HStack(spacing: 8) {
                Image(systemName: speech.isListening ? "waveform" : "mic.slash.fill")
                    .foregroundStyle(speech.isListening ? Theme.accent : Theme.textTertiary)
                    .symbolEffect(.variableColor.iterative, isActive: speech.isListening)
                Text(speech.isListening ? "Listening for your call-out…" : (speech.isAuthorized ? "Mic paused" : "Speech unavailable"))
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                if !engine.lastHeard.isEmpty {
                    Text("“\(engine.lastHeard)”")
                        .font(.caption2).foregroundStyle(Theme.textTertiary).lineLimit(1)
                }
            }
        } else {
            Label("Speech off — swipe or tap Confirm to advance", systemImage: "mic.slash.fill")
                .font(.caption).foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
