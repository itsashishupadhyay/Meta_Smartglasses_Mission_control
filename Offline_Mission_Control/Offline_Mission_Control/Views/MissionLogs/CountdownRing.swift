//
//  CountdownRing.swift
//  Offline_Mission_Control
//
//  Inverse countdown ring for a mission task (counts down from the task's estimated minutes).
//  Advisory only — reaching zero never advances the procedure.
//

import SwiftUI

struct CountdownRing: View {
    let remaining: Int
    let total: Int
    var size: CGFloat = 92

    private var fraction: CGFloat { total > 0 ? CGFloat(remaining) / CGFloat(total) : 0 }

    private var ringColor: Color {
        if remaining == 0 { return Theme.danger }
        if fraction < 0.25 { return Theme.warn }
        return Theme.accent
    }

    private var lineWidth: CGFloat { size >= 70 ? 8 : 5 }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.10), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, fraction))
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.9), value: remaining)
            VStack(spacing: 1) {
                Text(SessionStatsTracker.mmss(TimeInterval(remaining)))
                    .font(.telemetry(max(11, size * 0.2), weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                if size >= 64 {
                    Text("REMAIN")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(remaining / 60) minutes \(remaining % 60) seconds remaining")
    }
}
