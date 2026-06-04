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
        VStack(alignment: .leading, spacing: 8) {
            Label("IMU · iPhone Core Motion", systemImage: "gyroscope")
                .font(.headline)

            if !motion.isAvailable {
                Text("Device motion is unavailable on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                    GridRow {
                        Text("Attitude").bold()
                        Text("R \(MotionService.deg(sample.roll))°  P \(MotionService.deg(sample.pitch))°  Y \(MotionService.deg(sample.yaw))°")
                    }
                    GridRow {
                        Text("Rotation").bold()
                        Text(format(sample.rotationRate))
                    }
                    GridRow {
                        Text("Accel").bold()
                        Text(format(sample.userAcceleration))
                    }
                }
                .font(.system(.caption, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func format(_ vector: Vector3) -> String {
        String(format: "x %+.2f  y %+.2f  z %+.2f", vector.x, vector.y, vector.z)
    }
}
