//
//  IMUPanel.swift
//  Offline_Mission_Control
//
//  Live readout of the iPhone IMU (Core Motion). The glasses' own IMU is not exposed by the
//  DAT Developer Preview, so this reflects phone motion.
//

import SwiftUI

struct IMUPanel: View {
    var motion: MotionService

    var body: some View {
        let sample = motion.sample
        VStack(alignment: .leading, spacing: 10) {
            Text("iPhone Core Motion")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)

            if !motion.isAvailable {
                Text("Device motion is unavailable on this device.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    row("Attitude", "R \(MotionService.deg(sample.roll))°  P \(MotionService.deg(sample.pitch))°  Y \(MotionService.deg(sample.yaw))°")
                    row("Rotation", format(sample.rotationRate))
                    row("Accel", format(sample.userAcceleration))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label.uppercased())
                .font(.telemetry(11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.telemetry(12))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func format(_ vector: Vector3) -> String {
        String(format: "x %+.2f  y %+.2f  z %+.2f", vector.x, vector.y, vector.z)
    }
}
