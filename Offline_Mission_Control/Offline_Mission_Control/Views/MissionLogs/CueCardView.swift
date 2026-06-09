//
//  CueCardView.swift
//  Offline_Mission_Control
//
//  One mission state rendered as a cue card: type, task, the proxy object(s) to show, the spoken
//  cue text, the phrase to say to confirm, and the countdown / status footer.
//

import SwiftUI

struct CueCardView: View {
    let state: MissionState
    let isActivated: Bool
    let isComplete: Bool
    let remaining: Int
    let total: Int
    var isConfirmed: Bool = false
    var onReEnable: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                header
                // Title + a compact countdown beside it (so the timer doesn't push the details away).
                HStack(alignment: .top, spacing: 12) {
                    Text(state.taskName)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if isActivated {
                        CountdownRing(remaining: remaining, total: total, size: 58)
                    }
                }

                // Scrollable mission text log (the long cue body can exceed the card height).
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        if !state.objectTrigger.isEmpty { lookForRow }
                        cueText
                        if let expected = state.expectedIndication, !expected.isEmpty { sayRow(expected) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .opacity(isConfirmed ? 0.45 : 1)   // grey out a confirmed step (detail kept, not replaced)

            footer
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isActivated ? 2 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if isConfirmed {
                Label("DONE", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 10, weight: .bold)).tracking(1)
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Theme.accentGreen))
                    .padding(12)
            }
        }
    }

    private var borderColor: Color {
        if isConfirmed { return Theme.accentGreen.opacity(0.5) }
        return typeTint.opacity(isActivated ? 0.7 : 0.35)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(typeBadge)
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(typeTint))
            Text(state.stateID)
                .font(.telemetry(12, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            if let crew = state.crew {
                Label(crew, systemImage: "person.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var lookForRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOOK FOR").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(Theme.textTertiary)
            ForEach(Array(state.objectTrigger.enumerated()), id: \.offset) { _, trigger in
                HStack(spacing: 8) {
                    Circle().fill(DetectionPalette.color(for: trigger.cocoClass)).frame(width: 9, height: 9)
                    Text(trigger.represents ?? trigger.cocoClass.capitalized)
                        .font(.subheadline).foregroundStyle(Theme.textPrimary)
                    Text("(\(trigger.cocoClass))")
                        .font(.telemetry(11)).foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).fill(Color.white.opacity(0.03)))
    }

    private var cueText: some View {
        Text(state.messageLog)
            .font(.callout)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func sayRow(_ expected: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("SAY TO CONFIRM", systemImage: "mic.fill")
                .font(.system(size: 9, weight: .semibold)).tracking(1.2)
                .foregroundStyle(Theme.accent)
            Text("“\(expected)”")
                .font(.subheadline.italic())
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).fill(Theme.accent.opacity(0.08)))
    }

    @ViewBuilder private var footer: some View {
        if isComplete {
            Label("Procedure complete", systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundStyle(Theme.accentGreen)
        } else if isConfirmed {
            HStack(spacing: 12) {
                Label("Confirmed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accentGreen)
                Spacer(minLength: 8)
                Button { onReEnable?() } label: {
                    Label("Re-enable", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .overlay(Capsule().strokeBorder(Theme.surfaceStroke, lineWidth: 1))
                        .foregroundStyle(Theme.textPrimary)
                }
                .buttonStyle(.plain)
            }
        } else if isActivated {
            Label("In progress — say the call-out above (or tap Confirm) to advance", systemImage: "dot.radiowaves.left.and.right")
                .font(.caption)
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "viewfinder").foregroundStyle(Theme.textTertiary)
                Text("Show the object to begin · est. \(state.approxTimeMin) min")
                    .font(.caption).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var typeTint: Color {
        switch state.type {
        case .task, .gate: Theme.accent
        case .contingency: Theme.warn
        case .getAhead: Theme.textSecondary
        case .terminal: Theme.accentGreen
        }
    }

    private var typeBadge: String {
        switch state.type {
        case .task: "TASK"
        case .gate: "GATE"
        case .contingency: "CONTINGENCY"
        case .getAhead: "GET-AHEAD"
        case .terminal: "COMPLETE"
        }
    }
}
