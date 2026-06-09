//
//  ModelSettingsSheet.swift
//  Offline_Mission_Control
//
//  Opened from the model chip in the status header. Lets the user choose which on-device
//  detection model to run, with a short "when to use this" note under each. Selecting a model
//  writes through to AppSettings, which reloads the detector — same flow as the other sheets.
//  Models that haven't been generated yet are shown but disabled.
//

import SwiftUI

struct ModelSettingsSheet: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(DetectionModelOption.all) { model in
                        ModelRow(model: model, isSelected: settings.modelID == model.id) {
                            withAnimation(.snappy(duration: 0.2)) { settings.modelID = model.id }
                        }
                    }
                    footer
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Detection Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .tint(Theme.accent)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(28)
        .preferredColorScheme(.dark)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Adding more models", systemImage: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Generate models with tools/convert_models.py, which exports them to Resources/. COCO and Open Images V7 have public checkpoints. Objects365 (365), LVIS (1203) and PASCAL VOC (20) have no drop-in Core ML checkpoint and require training — see the README.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .padding(.top, 4)
    }
}

private struct ModelRow: View {
    let model: DetectionModelOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 12) {
                    Image(systemName: model.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.displayName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        HStack(spacing: 6) {
                            Text(model.dataset)
                            Text("· \(model.classCount) classes")
                            Text("· \(model.approxSize)")
                        }
                        .font(.telemetry(11))
                        .foregroundStyle(Theme.textTertiary)
                    }

                    Spacer(minLength: 8)
                    selectionIndicator
                }

                Text(model.useCase)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !model.isAvailable {
                    Label("Not added — run tools/convert_models.py", systemImage: "arrow.down.circle")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.warn)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.10) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent.opacity(0.5) : Theme.hairline, lineWidth: 1)
            )
            .opacity(model.isAvailable ? 1 : 0.55)
            .contentShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!model.isAvailable)
    }

    @ViewBuilder private var selectionIndicator: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Theme.accent : Theme.surfaceStroke, lineWidth: 2)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle().fill(Theme.accent).frame(width: 12, height: 12)
            }
        }
    }
}
