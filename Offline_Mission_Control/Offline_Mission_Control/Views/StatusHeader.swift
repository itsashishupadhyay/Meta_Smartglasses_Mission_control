//
//  StatusHeader.swift
//  Offline_Mission_Control
//
//  Compact status line: stream state + fps, device name, display capability, model status.
//

import SwiftUI

struct StatusHeader: View {
    var vm: MissionControlViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(vm.isRunning ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(vm.statusText)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                if vm.isRunning {
                    Text("\(Int(vm.fps)) fps")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Label(vm.wearables.primaryDeviceName ?? "No device", systemImage: "eyeglasses")
                if vm.canUseHUD {
                    Label("Display", systemImage: "sparkles.tv").foregroundStyle(.blue)
                }
                modelBadge
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var modelBadge: some View {
        switch vm.detectorStatus {
        case .ready:
            Label("Model ready", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        case .modelMissing:
            Label("Model missing", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .failed:
            Label("Model error", systemImage: "xmark.octagon.fill").foregroundStyle(.red)
        case .notLoaded:
            Label("Loading model…", systemImage: "hourglass")
        }
    }
}
