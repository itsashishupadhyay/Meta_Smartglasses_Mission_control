//
//  ContentView.swift
//  Offline_Mission_Control
//
//  Root view. Owns the orchestrator view model bound to the shared Wearables instance.
//

import MWDATCore
import SwiftUI

struct ContentView: View {
    @State private var viewModel = MissionControlViewModel(wearablesInterface: Wearables.shared)
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            HomeView(vm: viewModel)
        } else {
            OnboardingView(vm: viewModel) { hasCompletedOnboarding = true }
        }
    }
}
