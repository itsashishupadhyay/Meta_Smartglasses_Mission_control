//
//  OnboardingViewModel.swift
//  Offline_Mission_Control
//
//  Drives the first-launch flow: Wi-Fi/Local Network → Meta AI connection → camera →
//  connectivity check → main UI. Reuses the shared MissionControlViewModel so registration,
//  permissions, and the device session are the same instances the app uses afterward.
//

import Network
import Observation
import SwiftUI

@Observable
@MainActor
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome, network, metaConnect, camera, check
    }
    enum CheckState: Equatable { case idle, running, passed, failed(String) }

    var step: Step = .welcome
    var wifiConnected = false
    var localNetworkRequested = false
    var cameraRequesting = false
    var cameraGranted = false
    var check: CheckState = .idle

    @ObservationIgnored private let vm: MissionControlViewModel
    @ObservationIgnored private var pathMonitor: NWPathMonitor?

    init(vm: MissionControlViewModel) {
        self.vm = vm
        startWifiMonitor()
    }

    isolated deinit { pathMonitor?.cancel() }

    var isRegistered: Bool { vm.wearables.isRegistered }
    var isConnecting: Bool { vm.wearables.isConnecting }
    var deviceName: String? { vm.wearables.primaryDeviceName }

    func advance() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next }
    }

    func requestLocalNetwork() {
        LocalNetworkPermission.prompt()
        localNetworkRequested = true
    }

    func connectMeta() { vm.wearables.connect() }

    func requestCamera() async {
        cameraRequesting = true
        cameraGranted = await vm.requestCameraPermission()
        cameraRequesting = false
    }

    func runCheck() async {
        check = .running
        if let error = await vm.runCommCheck() {
            check = .failed(error)
        } else {
            check = .passed
        }
    }

    private func startWifiMonitor() {
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = (path.status == .satisfied)
            guard let self else { return }
            Task { @MainActor in self.wifiConnected = connected }
        }
        monitor.start(queue: .global(qos: .utility))
        pathMonitor = monitor
    }
}
