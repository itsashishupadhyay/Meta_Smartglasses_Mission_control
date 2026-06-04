//
//  LocalNetworkPermission.swift
//  Offline_Mission_Control
//
//  The Meta DAT camera video stream uses a Wi-Fi / local-network transport (QUIC/WARP).
//  iOS silently blocks local-network traffic until the user grants the "Local Network"
//  permission — and that prompt only appears once the app actually browses the local network.
//  Starting a brief Bonjour browse here forces iOS to (a) show the permission prompt and
//  (b) list the app under Settings ▸ Privacy & Security ▸ Local Network so it can be enabled.
//
//  The browsed service type must be declared in Info.plist's NSBonjourServices (we declare
//  `_bonjour._tcp`).
//

import Network

enum LocalNetworkPermission {
    private static var browser: NWBrowser?

    @MainActor
    static func prompt() {
        guard browser == nil else { return }
        let params = NWParameters()
        params.includePeerToPeer = true
        let newBrowser = NWBrowser(for: .bonjour(type: "_bonjour._tcp", domain: nil), using: params)
        newBrowser.stateUpdateHandler = { _ in }
        newBrowser.start(queue: .main)
        browser = newBrowser

        // Keep it alive briefly so the prompt fires, then tear it down.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            newBrowser.cancel()
            browser = nil
        }
    }
}
