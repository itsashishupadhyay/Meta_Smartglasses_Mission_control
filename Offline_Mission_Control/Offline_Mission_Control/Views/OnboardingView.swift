//
//  OnboardingView.swift
//  Offline_Mission_Control
//
//  First-launch permission + connectivity flow. Gates entry to the main UI until Local
//  Network, Meta AI connection, and camera access are granted and a connectivity check passes.
//

import SwiftUI

struct OnboardingView: View {
    @State private var model: OnboardingViewModel
    private let onComplete: () -> Void

    init(vm: MissionControlViewModel, onComplete: @escaping () -> Void) {
        _model = State(initialValue: OnboardingViewModel(vm: vm))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 24) {
            ProgressDots(total: OnboardingViewModel.Step.allCases.count, index: model.step.rawValue)
                .padding(.top, 28)
            Spacer()
            content
                .transition(.opacity)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .missionBackground()
        .animation(.easeInOut(duration: 0.25), value: model.step)
        .animation(.easeInOut(duration: 0.25), value: model.check)
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .welcome: welcome
        case .network: network
        case .metaConnect: metaConnect
        case .camera: camera
        case .check: check
        }
    }

    private var welcome: some View {
        StepScaffold(
            icon: "eyeglasses",
            title: "Offline Mission Control",
            message: "Real-time object detection on your Meta glasses. Let's grant a few permissions and verify the connection before we start."
        ) {
            Button("Get Started") { model.advance() }
                .buttonStyle(.missionProminent)
        }
    }

    private var network: some View {
        StepScaffold(
            icon: "wifi",
            title: "Wi-Fi & Local Network",
            message: "The glasses' camera feed streams over Wi-Fi. Turn Wi-Fi ON, and tap Allow when iOS asks for Local Network access."
        ) {
            StatusRow(ok: model.wifiConnected,
                      okText: "Wi-Fi connected",
                      badText: "Turn Wi-Fi on in Settings")
            StatusRow(ok: model.localNetworkRequested,
                      okText: "Local Network requested — tap Allow",
                      badText: "Local Network not requested yet")
            Button("Allow Local Network") { model.requestLocalNetwork() }
                .buttonStyle(.missionSecondary)
            Button("Continue") { model.advance() }
                .buttonStyle(.missionProminent)
        }
    }

    private var metaConnect: some View {
        StepScaffold(
            icon: "link",
            title: "Connect to Meta AI",
            message: "Link this app to the Meta AI companion app to reach your glasses. You'll bounce to Meta AI and back."
        ) {
            if model.isRegistered {
                StatusRow(ok: true, okText: "Connected to Meta AI", badText: "")
                Button("Continue") { model.advance() }
                    .buttonStyle(.missionProminent)
            } else {
                Button(model.isConnecting ? "Connecting…" : "Connect Glasses") { model.connectMeta() }
                    .buttonStyle(.missionProminent)
                    .disabled(model.isConnecting)
                if model.isConnecting { ProgressView().tint(Theme.accent) }
            }
        }
    }

    private var camera: some View {
        StepScaffold(
            icon: "camera",
            title: "Camera Access",
            message: "Grant access to the glasses camera. The prompt appears in the Meta AI app."
        ) {
            if model.cameraGranted {
                StatusRow(ok: true, okText: "Camera access granted", badText: "")
                Button("Continue") { model.advance() }
                    .buttonStyle(.missionProminent)
            } else {
                Button(model.cameraRequesting ? "Requesting…" : "Grant Camera Access") {
                    Task { await model.requestCamera() }
                }
                .buttonStyle(.missionProminent)
                .disabled(model.cameraRequesting)
            }
        }
    }

    private var check: some View {
        StepScaffold(
            icon: "checkmark.shield",
            title: "Connectivity Check",
            message: "A quick check that the app can reach your glasses before we begin."
        ) {
            switch model.check {
            case .idle:
                Button("Run Check") { Task { await model.runCheck() } }
                    .buttonStyle(.missionProminent)
            case .running:
                ProgressView("Checking connection…").tint(Theme.accent)
            case .passed:
                StatusRow(ok: true, okText: "All systems go", badText: "")
                Button("Enter Mission Control") { onComplete() }
                    .buttonStyle(.missionProminent)
            case .failed(let message):
                StatusRow(ok: false, okText: "", badText: message)
                HStack(spacing: 12) {
                    Button("Retry") { Task { await model.runCheck() } }
                        .buttonStyle(.missionSecondary)
                    Button("Skip Anyway") { onComplete() }
                        .buttonStyle(.missionProminent)
                }
            }
        }
    }
}

// MARK: - Building blocks

private struct StepScaffold<Controls: View>: View {
    let icon: String
    let title: String
    let message: String
    @ViewBuilder var controls: Controls

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 116, height: 116)
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(Theme.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            Text(title)
                .font(.title.bold())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 12) { controls }
                .padding(.top, 8)
        }
    }
}

private struct StatusRow: View {
    let ok: Bool
    let okText: String
    let badText: String

    var body: some View {
        Label(ok ? okText : badText, systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.circle")
            .foregroundStyle(ok ? Theme.accentGreen : Theme.warn)
            .font(.subheadline)
            .multilineTextAlignment(.leading)
    }
}

private struct ProgressDots: View {
    let total: Int
    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? Theme.accent : Color.white.opacity(0.18))
                    .frame(width: i == index ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut, value: index)
    }
}
