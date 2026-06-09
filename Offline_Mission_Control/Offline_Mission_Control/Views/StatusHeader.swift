//
//  StatusHeader.swift
//  Offline_Mission_Control
//
//  A slim system-status strip: connected device, optional Display capability, and the active
//  Core ML model. The model chip is tappable — it opens the model picker (same sheet flow as
//  the camera/detection settings).
//

import SwiftUI

struct StatusHeader: View {
    var vm: MissionControlViewModel
    var onSelectModel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            chip(icon: "eyeglasses", text: vm.wearables.primaryDeviceName ?? "No device", tint: Theme.textSecondary)
            Spacer(minLength: 0)
            modelChip
        }
    }

    private var modelChip: some View {
        Button(action: onSelectModel) {
            HStack(spacing: 5) {
                Image(systemName: statusInfo.icon).font(.caption2.weight(.semibold))
                Text(modelText).font(.caption.weight(.medium)).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.6)
            }
            .foregroundStyle(statusInfo.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select detection model")
    }

    private var modelText: String {
        switch vm.detectorStatus {
        case .ready: vm.settings.selectedModel.displayName
        case .modelMissing: "Model missing"
        case .failed: "Model error"
        case .notLoaded: "Loading…"
        }
    }

    private var statusInfo: (icon: String, tint: Color) {
        switch vm.detectorStatus {
        case .ready: ("checkmark.seal.fill", Theme.accentGreen)
        case .modelMissing: ("exclamationmark.triangle.fill", Theme.warn)
        case .failed: ("xmark.octagon.fill", Theme.danger)
        case .notLoaded: ("hourglass", Theme.textTertiary)
        }
    }

    private func chip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2.weight(.semibold))
            Text(text).font(.caption.weight(.medium)).lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }
}
