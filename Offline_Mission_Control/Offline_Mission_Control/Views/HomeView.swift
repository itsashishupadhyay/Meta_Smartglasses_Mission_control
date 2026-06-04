//
//  HomeView.swift
//  Offline_Mission_Control
//
//  Top-level screen. Shows the connect flow until registered, then the mission-control UI:
//  live detection overlay, summary, controls, and IMU readout.
//

import SwiftUI

struct HomeView: View {
    var vm: MissionControlViewModel

    var body: some View {
        NavigationStack {
            Group {
                if vm.wearables.isRegistered {
                    missionControl
                } else {
                    ConnectView(vm: vm)
                }
            }
            .navigationTitle("Mission Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if vm.wearables.isRegistered {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Disconnect") { vm.wearables.disconnect() }
                    }
                }
            }
        }
        .task {
            LocalNetworkPermission.prompt()
            await vm.loadModel()
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

                DetectionOverlayView(image: vm.currentFrame, detections: vm.detections)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack {
                    Image(systemName: "viewfinder")
                    Text(vm.summaryLine).font(.callout.weight(.medium))
                    Spacer()
                }
                .foregroundStyle(.primary)

                ControlsBar(vm: vm)

                IMUPanel(motion: vm.motion)
                    .padding()
                    .background(.quaternary.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
}
