//
//  Theme.swift
//  Offline_Mission_Control
//
//  The "Mission Control" design system: an always-dark, charcoal canvas with translucent
//  glass cards, an electric cyan/green accent, and monospaced telemetry. Everything visual
//  in the app draws from the tokens and reusable components defined here so the look stays
//  consistent and release-ready.
//

import SwiftUI

// MARK: - Design tokens

enum Theme {
    // Canvas
    static let bg = Color(red: 0.035, green: 0.043, blue: 0.055)        // near-black charcoal
    static let bgElevated = Color(red: 0.07, green: 0.083, blue: 0.10)

    // Accents
    static let accent = Color(red: 0.18, green: 0.90, blue: 0.84)       // electric cyan
    static let accentGreen = Color(red: 0.24, green: 0.91, blue: 0.53)  // signal green
    static let danger = Color(red: 1.0, green: 0.33, blue: 0.36)
    static let warn = Color(red: 1.0, green: 0.72, blue: 0.24)
    static let onAccent = Color(red: 0.02, green: 0.05, blue: 0.06)     // text on bright accent

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.40)

    // Surfaces / strokes
    static let surface = Color.white.opacity(0.05)
    static let surfaceStroke = Color.white.opacity(0.10)
    static let hairline = Color.white.opacity(0.07)

    // Metrics
    static let cardRadius: CGFloat = 20
    static let controlRadius: CGFloat = 14
    static let pillRadius: CGFloat = 11

    // Gradients
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentGreen], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Font {
    /// Monospaced telemetry font (fps, resolution, IMU readouts, confidence values).
    static func telemetry(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Surface modifiers

private struct GlassCardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
            )
    }
}

private struct MissionBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            ZStack {
                Theme.bg
                RadialGradient(
                    colors: [Theme.accent.opacity(0.10), .clear],
                    center: .top, startRadius: 0, endRadius: 460
                )
            }
            .ignoresSafeArea()
        )
    }
}

extension View {
    /// Wraps content in a translucent, hairline-bordered glass card.
    func glassCard(padding: CGFloat = 16, radius: CGFloat = Theme.cardRadius) -> some View {
        modifier(GlassCardModifier(padding: padding, radius: radius))
    }

    /// Applies the dark mission-control canvas (with a subtle top accent glow).
    func missionBackground() -> some View {
        modifier(MissionBackgroundModifier())
    }
}

// MARK: - Shared components

/// Small uppercase, letter-spaced section header with an optional trailing accessory.
struct SectionHeader<Trailing: View>: View {
    private let title: String
    private let systemImage: String?
    private let trailing: Trailing

    init(title: String, systemImage: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.semibold))
            }
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.7)
            Spacer(minLength: 8)
            trailing
        }
        .foregroundStyle(Theme.textTertiary)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String, systemImage: String? = nil) {
        self.init(title: title, systemImage: systemImage) { EmptyView() }
    }
}

/// A translucent capsule used for transient status (REC / fps / resolution).
struct StatusPill<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) { content }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.surfaceStroke, lineWidth: 1))
    }
}

/// A subtle, circular translucent icon button — used as the "hidden" settings entry points.
struct GlassIconButton: View {
    let systemName: String
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Theme.surfaceStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// A pulsing status dot (a soft expanding ring behind a solid core).
struct PulsingDot: View {
    var color: Color
    var size: CGFloat = 8
    @State private var animating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .scaleEffect(animating ? 2.4 : 1)
                    .opacity(animating ? 0 : 0.7)
            )
            .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: animating)
            .onAppear { animating = true }
    }
}

/// A vertical hairline separator for use inside pills/rows.
struct VBar: View {
    var height: CGFloat = 12
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: height)
    }
}

/// A selectable settings row with a radio indicator, used across the settings sheets.
struct OptionRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                        .frame(width: 26)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.telemetry(12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Theme.accent : Theme.surfaceStroke, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Theme.accent).frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.10) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent.opacity(0.5) : Theme.hairline, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Button styles

/// Prominent accent-gradient call-to-action button.
struct MissionProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Theme.onAccent)
            .background(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(Theme.accentGradient)
            )
            .shadow(color: Theme.accent.opacity(0.3), radius: 10, y: 5)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Subtle glass/secondary button.
struct MissionSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Theme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == MissionProminentButtonStyle {
    static var missionProminent: MissionProminentButtonStyle { .init() }
}

extension ButtonStyle where Self == MissionSecondaryButtonStyle {
    static var missionSecondary: MissionSecondaryButtonStyle { .init() }
}

/// A pill-style toggle "chip" used in the controls bar.
struct ToggleChip: View {
    @Binding var isOn: Bool
    var title: String
    var systemImage: String
    var enabled: Bool = true

    var body: some View {
        Button {
            guard enabled else { return }
            withAnimation(.snappy(duration: 0.2)) { isOn.toggle() }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                Text(title).fontWeight(.medium)
                Spacer(minLength: 4)
                Circle()
                    .fill(isOn ? Theme.accent : Color.white.opacity(0.18))
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(isOn ? Theme.accent.opacity(0.12) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .strokeBorder(isOn ? Theme.accent.opacity(0.45) : Theme.hairline, lineWidth: 1)
            )
            .foregroundStyle(isOn ? Theme.accent : Theme.textSecondary)
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
