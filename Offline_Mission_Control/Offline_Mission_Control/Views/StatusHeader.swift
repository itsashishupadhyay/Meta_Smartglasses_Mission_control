//
//  StatusHeader.swift
//  Offline_Mission_Control
//
//  A slim system-status strip: connected device, optional Display capability, and Core ML
//  model state — rendered as compact translucent chips beneath the navigation bar.
//

import SwiftUI

struct StatusHeader: View {
    var vm: MissionControlViewModel

    var body: some View {
        HStack(spacing: 8) {
            chip(icon: "eyeglasses", text: vm.wearables.primaryDeviceName ?? "No device", tint: Theme.textSecondary)
            if vm.canUseHUD {
                chip(icon: "sparkles.tv", text: "Display", tint: Theme.accent)
            }
            Spacer(minLength: 0)
            modelChip
        }
    }

    private var modelChip: some View {
        let info: (icon: String, text: String, tint: Color) = {
            switch vm.detectorStatus {
            case .ready: ("checkmark.seal.fill", "Model ready", Theme.accentGreen)
            case .modelMissing: ("exclamationmark.triangle.fill", "Model missing", Theme.warn)
            case .failed: ("xmark.octagon.fill", "Model error", Theme.danger)
            case .notLoaded: ("hourglass", "Loading model", Theme.textTertiary)
            }
        }()
        return chip(icon: info.icon, text: info.text, tint: info.tint)
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
