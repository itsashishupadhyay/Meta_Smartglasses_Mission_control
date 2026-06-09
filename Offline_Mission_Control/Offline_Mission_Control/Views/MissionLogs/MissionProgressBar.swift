//
//  MissionProgressBar.swift
//  Offline_Mission_Control
//
//  "STEP n OF total" + current section + active task name, with a linear progress fill.
//

import SwiftUI

struct MissionProgressBar: View {
    let done: Int
    let total: Int
    let section: String?
    let taskName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("STEP \(done) OF \(total)")
                    .font(.caption.weight(.semibold)).tracking(1.4)
                    .foregroundStyle(Theme.accent)
                Spacer(minLength: 8)
                if let section {
                    Text(section)
                        .font(.caption2).foregroundStyle(Theme.textTertiary).lineLimit(1)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Theme.accentGradient)
                        .frame(width: total > 0 ? geo.size.width * CGFloat(done) / CGFloat(total) : 0)
                        .animation(.snappy, value: done)
                }
            }
            .frame(height: 5)
            Text(taskName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCard(padding: 14)
    }
}
