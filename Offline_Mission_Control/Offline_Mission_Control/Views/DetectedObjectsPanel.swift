//
//  DetectedObjectsPanel.swift
//  Offline_Mission_Control
//
//  A fixed-height, two-page card. Page 1 (default) is the live read-out of what the glasses
//  currently see — a ranked, scrolling list of detected classes. Swipe right to reveal page 2,
//  a session "leaderboard": per-object frame counts, the time each was detected (MM:SS, derived
//  from the session frame rate), and a live session timer. Also hosts the detection settings
//  button (the second "hidden" entry point).
//

import SwiftUI

struct DetectedObjectsPanel: View {
    var vm: MissionControlViewModel
    var onOpenSettings: () -> Void

    enum Page: Int { case leaderboard = 0, detected = 1 }
    @State private var page: Page = .detected

    /// Constant content height so the card doesn't resize as objects come and go.
    private let contentHeight: CGFloat = 236

    private var totalCount: Int { vm.summary.reduce(0) { $0 + $1.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            // Leaderboard is to the LEFT of Detected, so a right-swipe reveals it.
            TabView(selection: $page) {
                leaderboardPage.tag(Page.leaderboard)
                detectedPage.tag(Page.detected)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: contentHeight)
            .animation(.snappy, value: page)
        }
        .glassCard()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text(page == .detected ? "DETECTED" : "SESSION LOG")
                .font(.caption.weight(.semibold))
                .tracking(1.7)
                .foregroundStyle(Theme.textTertiary)
                .contentTransition(.opacity)

            if page == .detected, !vm.summary.isEmpty {
                Text("\(totalCount)")
                    .font(.telemetry(11, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accent))
                    .contentTransition(.numericText())
            }

            if vm.sessionStats.hasData {
                sessionTimerChip
            }

            Spacer(minLength: 8)

            PageDots(count: 2, index: page.rawValue)
            GlassIconButton(systemName: "slider.horizontal.3", size: 30, action: onOpenSettings)
                .accessibilityLabel("Detection settings")
        }
    }

    private var sessionTimerChip: some View {
        HStack(spacing: 5) {
            if vm.isRunning {
                Circle().fill(Theme.accentGreen).frame(width: 6, height: 6)
            }
            Text(SessionStatsTracker.mmss(vm.sessionStats.elapsed))
                .font(.telemetry(12, weight: .medium))
                .foregroundStyle(vm.isRunning ? Theme.accentGreen : Theme.textSecondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }

    // MARK: - Detected page

    @ViewBuilder private var detectedPage: some View {
        if vm.summary.isEmpty {
            emptyDetected
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(vm.summary) { item in
                        ObjectRow(item: item)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.96).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.bottom, 4)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: vm.summary)
        }
    }

    private var emptyDetected: some View {
        VStack(spacing: 10) {
            Image(systemName: vm.isRunning ? "dot.radiowaves.left.and.right" : "viewfinder.circle")
                .font(.largeTitle)
                .foregroundStyle(vm.isRunning ? Theme.accent : Theme.textTertiary)
                .symbolEffect(.variableColor.iterative, isActive: vm.isRunning)
            Text(vm.isRunning ? "Scanning…" : "Detection paused")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            Text(vm.isRunning
                 ? "Point the glasses at objects to identify them."
                 : "Start detection to identify objects in view.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
    }

    // MARK: - Leaderboard page

    @ViewBuilder private var leaderboardPage: some View {
        if vm.sessionStats.leaderboard.isEmpty {
            emptyLeaderboard
        } else {
            VStack(spacing: 12) {
                leaderboardSummary
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 9) {
                        ForEach(Array(vm.sessionStats.leaderboard.enumerated()), id: \.element.id) { index, stat in
                            LeaderboardRow(
                                rank: index + 1,
                                stat: stat,
                                maxFrames: vm.sessionStats.maxFrames,
                                time: SessionStatsTracker.mmss(vm.sessionStats.detectedTime(stat))
                            )
                        }
                    }
                    .padding(.bottom, 4)
                }
                .animation(.snappy, value: vm.sessionStats.leaderboard)
            }
        }
    }

    private var leaderboardSummary: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SESSION TIME")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(Theme.textTertiary)
                HStack(spacing: 7) {
                    if vm.isRunning { PulsingDot(color: Theme.accentGreen, size: 7) }
                    Text(SessionStatsTracker.mmss(vm.sessionStats.elapsed))
                        .font(.telemetry(24, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(vm.sessionStats.leaderboard.count) objects")
                    .font(.telemetry(12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text("\(vm.sessionStats.totalFrames) frames")
                    .font(.telemetry(12))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var emptyLeaderboard: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy")
                .font(.largeTitle)
                .foregroundStyle(Theme.textTertiary)
            Text("No session data yet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            Text("Start detection to log how often each object is seen.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
    }
}

// MARK: - Rows

private struct ObjectRow: View {
    let item: ClassCount

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(DetectionPalette.color(for: item.label))
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(item.label.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if item.count > 1 {
                        Text("×\(item.count)")
                            .font(.telemetry(11, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    Spacer(minLength: 4)
                    Text("\(Int((item.topConfidence * 100).rounded()))%")
                        .font(.telemetry(12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                ConfidenceBar(value: item.topConfidence)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let stat: ObjectSessionStat
    let maxFrames: Int
    let time: String

    var body: some View {
        let fraction = maxFrames > 0 ? CGFloat(stat.frames) / CGFloat(maxFrames) : 0
        let color = DetectionPalette.color(for: stat.label)
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.telemetry(13, weight: .bold))
                .foregroundStyle(rank <= 3 ? Theme.onAccent : Theme.textSecondary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(rank <= 3 ? Theme.accent : Color.white.opacity(0.08)))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(stat.label.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 4)
                    Text(time)
                        .font(.telemetry(12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text("\(stat.frames)f")
                        .font(.telemetry(11))
                        .foregroundStyle(Theme.textTertiary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06))
                        Capsule().fill(color.opacity(0.7))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ConfidenceBar: View {
    let value: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(Theme.accentGradient)
                    .frame(width: max(4, geo.size.width * CGFloat(min(max(value, 0), 1))))
            }
        }
        .frame(height: 4)
    }
}

private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Theme.accent : Color.white.opacity(0.22))
                    .frame(width: i == index ? 16 : 6, height: 6)
            }
        }
        .animation(.snappy, value: index)
    }
}
