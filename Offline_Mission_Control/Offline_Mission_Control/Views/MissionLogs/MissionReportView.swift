//
//  MissionReportView.swift
//  Offline_Mission_Control
//
//  Full-screen post-mission scorecard, shown once every step is confirmed. Per step: timestamp,
//  how long it took, how long the target object was in view, how it was confirmed (voice
//  transcript / manual / override), and a snapshot of the target while it was present.
//

import SwiftUI

struct MissionReportView: View {
    let mission: Mission
    let records: [MissionStepRecord]
    var onExit: () -> Void

    private var totalDuration: TimeInterval { records.reduce(0) { $0 + $1.duration } }
    private var totalTargetSeen: TimeInterval { records.reduce(0) { $0 + $1.targetSeenSeconds } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    summary
                    ForEach(records) { record in
                        ReportRow(record: record)
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .missionBackground()
            .navigationTitle("Mission Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onExit() }.fontWeight(.semibold)
                }
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }

    private var summary: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(Theme.accentGreen)
            Text("Mission Complete").font(.title2.bold()).foregroundStyle(Theme.textPrimary)
            Text(mission.procedure.title)
                .font(.callout).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 0) {
                stat("STEPS", "\(records.count)")
                bar
                stat("TOTAL", SessionStatsTracker.mmss(totalDuration))
                bar
                stat("ON TARGET", SessionStatsTracker.mmss(totalTargetSeen))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.telemetry(17, weight: .bold)).foregroundStyle(Theme.accent)
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(1.2).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var bar: some View { Rectangle().fill(Theme.hairline).frame(width: 1, height: 30) }
}

private struct ReportRow: View {
    let record: MissionStepRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            snapshot
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(record.stateID).font(.telemetry(12, weight: .bold)).foregroundStyle(Theme.accent)
                    Spacer(minLength: 4)
                    Text(record.confirmedAt.formatted(date: .omitted, time: .standard))
                        .font(.telemetry(11)).foregroundStyle(Theme.textTertiary)
                }
                Text(record.taskName)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    metric(icon: "clock", value: SessionStatsTracker.mmss(record.duration))
                    metric(icon: "scope", value: SessionStatsTracker.mmss(record.targetSeenSeconds))
                    confirmBadge
                }
                if let transcript = record.confirmation.transcript {
                    Text("“\(transcript)”")
                        .font(.caption.italic()).foregroundStyle(Theme.textTertiary).lineLimit(3)
                }
            }
        }
        .glassCard(padding: 12)
    }

    private var snapshot: some View {
        Group {
            if let image = record.snapshot {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.05)
                    Image(systemName: "photo").foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .frame(width: 60, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private func metric(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(value).font(.telemetry(12, weight: .medium))
        }
        .foregroundStyle(Theme.textSecondary)
    }

    private var confirmBadge: some View {
        let tint: Color = {
            switch record.confirmation {
            case .voice: Theme.accentGreen
            case .manual: Theme.textSecondary
            case .override: Theme.warn
            }
        }()
        return Text(record.confirmation.label)
            .font(.system(size: 9, weight: .bold)).tracking(0.8)
            .foregroundStyle(tint)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.15)))
    }
}
