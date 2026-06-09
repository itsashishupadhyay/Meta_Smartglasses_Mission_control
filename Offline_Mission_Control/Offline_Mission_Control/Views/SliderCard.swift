//
//  SliderCard.swift
//  Offline_Mission_Control
//
//  A labelled slider in a glass card with a prominent monospaced value read-out. Shared by the
//  Detection settings sheet and the Mission Logs setup.
//

import SwiftUI

struct SliderCard: View {
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
