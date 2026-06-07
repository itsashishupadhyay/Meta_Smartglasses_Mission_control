//
//  HomeView.swift
//  Offline_Mission_Control
//
//  Top-level screen. Shows the connect flow until registered, then the mission-control UI:
//  system-status chips, the live camera stage, the detected-objects panel, primary controls,
//  and a collapsible telemetry card. The two settings sheets are opened from the "hidden"
//  on-stage / on-panel buttons.
//

import SwiftUI

struct HomeView: View {
    var vm: MissionControlViewModel

    @State private var showCameraSettings = false
    @State private var showDetectionSettings = false
    @State private var showTelemetry = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.wearables.isRegistered {
                    missionControl
                } else {
                    ConnectView(vm: vm)
                }
            }
            .missionBackground()
            .navigationTitle("Mission Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if vm.wearables.isRegistered {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Disconnect") { vm.wearables.disconnect() }
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .tint(Theme.accent)
        .task {
            LocalNetworkPermission.prompt()
            await vm.loadModel()
        }
        .sheet(isPresented: $showCameraSettings) {
            CameraSettingsSheet(settings: vm.settings)
        }
        .sheet(isPresented: $showDetectionSettings) {
            DetectionSettingsSheet(settings: vm.settings)
        }
        .alert(
            "Glasses error",
            isPresented: Binding(
                get: { vm.wearables.showError },
                set: { vm.wearables.showError = $0 }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.wearables.errorMessage)
        }
    }

    private var missionControl: some View {
        ScrollView {
            VStack(spacing: 16) {
                StatusHeader(vm: vm)

                CameraStage(vm: vm) { showCameraSettings = true }

                DetectedObjectsPanel(vm: vm) { showDetectionSettings = true }

                ControlsBar(vm: vm)

                telemetryCard
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }

    private var telemetryCard: some View {
        DisclosureGroup(isExpanded: $showTelemetry) {
            IMUPanel(motion: vm.motion)
                .padding(.top, 10)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gyroscope").font(.caption.weight(.semibold))
                Text("TELEMETRY").font(.caption.weight(.semibold)).tracking(1.7)
            }
            .foregroundStyle(Theme.textTertiary)
        }
        .tint(Theme.accent)
        .glassCard()
    }
}
