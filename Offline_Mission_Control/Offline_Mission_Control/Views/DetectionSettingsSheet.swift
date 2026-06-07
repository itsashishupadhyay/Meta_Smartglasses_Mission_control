//
//  DetectionSettingsSheet.swift
//  Offline_Mission_Control
//
//  The "hidden" detection control surface, opened from the objects panel. Tunes:
//   • Confidence — minimum score for a detection to count.
//   • Appear for — seconds an object must persist before it's shown + announced (0 = instant).
//   • Re-announce — minimum spacing between repeats of the same spoken label.
//

import SwiftUI

struct DetectionSettingsSheet: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    SliderCard(
                        title: "Confidence",
                        blurb: "Minimum score a detection needs before it appears. Raise it to cut false positives; lower it to catch more.",
                        valueText: "\(Int(settings.confidence * 100))%",
                        value: $settings.confidence,
                        range: 0.1...0.9,
                        step: 0.05,
                        minLabel: "10%",
                        maxLabel: "90%"
                    )

                    SliderCard(
                        title: "Appear For",
                        blurb: "How long an object must stay in view before it's shown and announced. Steadies the read-out and filters fleeting detections. Zero reacts to every frame.",
                        valueText: dwellText,
                        value: $settings.dwellSeconds,
                        range: 0...5,
                        step: 0.5,
                        minLabel: "Instant",
                        maxLabel: "5s"
                    )

                    SliderCard(
                        title: "Re-announce",
                        blurb: "Minimum time before the same object is spoken again, so announcements don't repeat too often.",
                        valueText: "\(Int(settings.reannounceSeconds))s",
                        value: $settings.reannounceSeconds,
                        range: 1...15,
                        step: 1,
                        minLabel: "1s",
                        maxLabel: "15s"
                    )
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Detection")
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

    private var dwellText: String {
        let value = settings.dwellSeconds
        if value <= 0 { return "Instant" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))s"
            : String(format: "%.1fs", value)
    }
}

/// A labelled slider in a glass card with a prominent monospaced value read-out.
private struct SliderCard: View {
    let title: String
    let blurb: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let minLabel: String
    let maxLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title) {
                Text(valueText)
                    .font(.telemetry(15, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: valueText)
            }

            Slider(value: $value, in: range, step: step)
                .tint(Theme.accent)

            HStack {
                Text(minLabel)
                Spacer()
                Text(maxLabel)
            }
            .font(.telemetry(11))
            .foregroundStyle(Theme.textTertiary)

            Text(blurb)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
