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
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "eyeglasses")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Connect your Meta glasses")
                .font(.title2.bold())
            Text("Link this app to the Meta AI app to access the glasses camera. Make sure your glasses are paired and Developer Mode is enabled.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Text("Status: \(vm.wearables.registrationLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                vm.wearables.connect()
            } label: {
                Label("Connect Glasses", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(vm.wearables.isConnecting)
            .padding(.horizontal)
            Spacer()
        }
        .padding()
    }
}
