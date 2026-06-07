//
//  CameraSettingsSheet.swift
//  Offline_Mission_Control
//
//  The "hidden" camera control surface, opened from the on-stage settings button. Lets the
//  user pick the glasses camera resolution, frame rate, and video format. Changes write
//  straight through to AppSettings, which restarts the live stream when detection is running.
//

import SwiftUI

struct CameraSettingsSheet: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    section(
                        "Resolution",
                        "Higher resolution sharpens detection of small or distant objects but uses more power and wireless bandwidth."
                    ) {
                        VStack(spacing: 10) {
                            ForEach(CameraResolutionOption.allCases) { option in
                                OptionRow(
                                    title: option.title,
                                    subtitle: option.dimensionsText,
                                    systemImage: option.systemImage,
                                    isSelected: settings.resolution == option
                                ) {
                                    withAnimation(.snappy(duration: 0.2)) { settings.resolution = option }
                                }
                            }
                        }
                    }

                    section(
                        "Frame Rate",
                        "Frames per second streamed from the glasses. Detection runs as fast as the device allows; lower rates save battery and reduce heat."
                    ) {
                        FrameRateSelector(value: $settings.frameRate)
                    }

                    Label(
                        "Changes apply instantly — the stream restarts automatically while detection is running.",
                        systemImage: "bolt.horizontal.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .tint(Theme.accent)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(28)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, _ blurb: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            content()
            Text(blurb)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

/// Horizontal preset selector for the camera frame rate.
private struct FrameRateSelector: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppSettings.frameRatePresets, id: \.self) { fps in
                let selected = value == fps
                Button {
                    withAnimation(.snappy(duration: 0.2)) { value = fps }
                } label: {
                    VStack(spacing: 2) {
                        Text("\(fps)").font(.telemetry(17, weight: .semibold))
                        Text("fps").font(.system(size: 9, weight: .semibold)).opacity(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? Theme.accent.opacity(0.16) : Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selected ? Theme.accent : Theme.hairline, lineWidth: 1)
                    )
                    .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
