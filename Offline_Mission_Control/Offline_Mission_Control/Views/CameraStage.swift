//
//  CameraStage.swift
//  Offline_Mission_Control
//
//  The hero camera surface: the live glasses feed with bounding boxes, a translucent status
//  pill (REC · fps · resolution), and the first "hidden" settings entry point — a subtle
//  on-stage button that opens the camera settings sheet.
//

import SwiftUI

struct CameraStage: View {
    var vm: MissionControlViewModel
    var onOpenCameraSettings: () -> Void

    var body: some View {
        DetectionOverlayView(image: vm.currentFrame, detections: vm.detections)
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .overlay(alignment: .top) { topScrim }
            .overlay(alignment: .top) { topBar }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
    }

    private var topScrim: some View {
        LinearGradient(
            colors: [.black.opacity(0.45), .clear],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: 84)
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            statusPill
            Spacer()
            GlassIconButton(systemName: "slider.horizontal.3", action: onOpenCameraSettings)
                .accessibilityLabel("Camera settings")
        }
        .padding(12)
    }

    @ViewBuilder private var statusPill: some View {
        StatusPill {
            if vm.isReconfiguring {
                ProgressView().controlSize(.mini).tint(Theme.accent)
                Text("RECONFIG")
                    .font(.telemetry(11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            } else if vm.isRunning && !vm.camera.isStreaming {
                ProgressView().controlSize(.mini).tint(Theme.accent)
                Text("CONNECTING")
                    .font(.telemetry(11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            } else if vm.isRunning {
                PulsingDot(color: Theme.danger)
                Text("REC")
                    .font(.telemetry(12, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                VBar()
                Text("\(Int(vm.fps)) fps")
                    .font(.telemetry(12))
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText())
                VBar()
                Text(vm.settings.resolution.shortLabel)
                    .font(.telemetry(12))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Circle().fill(Theme.textTertiary).frame(width: 8, height: 8)
                Text("IDLE")
                    .font(.telemetry(12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .animation(.snappy, value: vm.isRunning)
    }
}
