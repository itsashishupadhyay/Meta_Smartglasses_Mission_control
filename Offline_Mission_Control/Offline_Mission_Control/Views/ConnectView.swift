//
//  ConnectView.swift
//  Offline_Mission_Control
//
//  Shown until the app is registered with the Meta AI companion app. Registration links the
//  app to the glasses and is required before any camera/display session can start.
//

import SwiftUI

struct ConnectView: View {
    var vm: MissionControlViewModel

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 132, height: 132)
                Image(systemName: "eyeglasses")
                    .font(.system(size: 58, weight: .light))
                    .foregroundStyle(Theme.accent)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 10) {
                Text("Connect your Meta glasses")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("Link this app to the Meta AI app to access the glasses camera. Make sure your glasses are paired and Developer Mode is enabled.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            HStack(spacing: 8) {
                Circle()
                    .fill(vm.wearables.isConnecting ? Theme.warn : Theme.textTertiary)
                    .frame(width: 7, height: 7)
                Text(vm.wearables.registrationLabel)
                    .font(.telemetry(12))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))

            Button {
                vm.wearables.connect()
            } label: {
                Label("Connect Glasses", systemImage: "link")
            }
            .buttonStyle(.missionProminent)
            .disabled(vm.wearables.isConnecting)
            .padding(.horizontal)
            .padding(.top, 4)

            Spacer()
        }
        .padding(24)
    }
}
