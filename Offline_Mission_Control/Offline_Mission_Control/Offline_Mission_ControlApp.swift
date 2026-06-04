//
//  Offline_Mission_ControlApp.swift
//  Offline_Mission_Control
//
//  App entry point. Configures the Meta Wearables Device Access Toolkit at launch and routes
//  the Meta AI registration callback URL back into the SDK.
//

import MWDATCore
import SwiftUI

@main
struct Offline_Mission_ControlApp: App {
    init() {
        do {
            try Wearables.configure()
        } catch {
            assertionFailure("Failed to configure Wearables SDK: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Task { _ = try? await Wearables.shared.handleUrl(url) }
                }
        }
    }
}
