//
//  ControlsBar.swift
//  Offline_Mission_Control
//
//  Primary actions: the prominent Start/Stop button plus audio and glasses-HUD toggles, with
//  app-controllable speech transport (pause/resume/stop). Detection tuning (confidence, dwell)
//  lives in the Detection settings sheet, opened from the objects panel.
//

import SwiftUI

struct ControlsBar: View {
    @Bindable var vm: MissionControlViewModel

    var body: some View {
        VStack(spacing: 12) {
            startStopButton

            HStack(spacing: 10) {
                ToggleChip(isOn: $vm.audioEnabled, title: "Audio", systemImage: "speaker.wave.2.fill")
                ToggleChip(isOn: $vm.hudEnabled, title: "Glasses HUD", systemImage: "eyeglasses", enabled: vm.canUseHUD)
            }

            if vm.audioEnabled {
                speechTransport
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy(duration: 0.22), value: vm.audioEnabled)
    }

    private var startStopButton: some View {
        Button {
            Task { await vm.toggleRunning() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: vm.isRunning ? "stop.fill" : "play.fill")
                Text(vm.isRunning ? "Stop Detection" : "Start Detection")
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(vm.isRunning ? Color.white : Theme.onAccent)
            .background {
                if vm.isRunning {
                    RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).fill(Theme.danger)
                } else {
                    RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).fill(Theme.accentGradient)
                }
            }
            .shadow(color: (vm.isRunning ? Theme.danger : Theme.accent).opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: vm.isRunning)
    }

    private var speechTransport: some View {
        HStack(spacing: 20) {
            Button {
                vm.announcer.isPaused ? vm.announcer.resume() : vm.announcer.pause()
            } label: {
                Image(systemName: vm.announcer.isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.title3)
            }
            Button {
                vm.announcer.stop()
            } label: {
                Image(systemName: "stop.circle.fill").font(.title3)
            }
            Spacer()
            Label("Voice output", systemImage: "waveform")
                .font(.caption)
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 4)
    }
}
