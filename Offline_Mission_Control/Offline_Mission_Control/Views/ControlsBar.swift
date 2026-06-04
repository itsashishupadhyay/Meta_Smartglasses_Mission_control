//
//  ControlsBar.swift
//  Offline_Mission_Control
//
//  Start/stop, audio (enable + pause/resume/stop), glasses-HUD toggle, and the detection
//  confidence threshold. Audio playback is fully app-controllable as required.
//

import SwiftUI

struct ControlsBar: View {
    @Bindable var vm: MissionControlViewModel

    var body: some View {
        VStack(spacing: 14) {
            Button {
                Task { await vm.toggleRunning() }
            } label: {
                Label(vm.isRunning ? "Stop" : "Start Detection",
                      systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .controlSize(.large)

            HStack(spacing: 16) {
                Toggle(isOn: $vm.audioEnabled) {
                    Label("Audio", systemImage: "speaker.wave.2.fill")
                }
                .toggleStyle(.button)

                Spacer()

                Button {
                    vm.announcer.isPaused ? vm.announcer.resume() : vm.announcer.pause()
                } label: {
                    Image(systemName: vm.announcer.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.title2)
                }
                .disabled(!vm.audioEnabled)

                Button {
                    vm.announcer.stop()
                } label: {
                    Image(systemName: "stop.circle.fill").font(.title2)
                }
                .disabled(!vm.audioEnabled)
            }

            Toggle(isOn: $vm.hudEnabled) {
                Label(vm.canUseHUD ? "Glasses HUD card" : "Glasses HUD (needs Display glasses)",
                      systemImage: "eyeglasses")
            }
            .disabled(!vm.canUseHUD)

            VStack(alignment: .leading, spacing: 2) {
                Text("Confidence threshold: \(Int(vm.confidenceThreshold * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $vm.confidenceThreshold, in: 0.1...0.9, step: 0.05)
            }
        }
    }
}
