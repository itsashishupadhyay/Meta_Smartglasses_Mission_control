//
//  WearablesManager.swift
//  Offline_Mission_Control
//
//  Wraps the DAT SDK's registration + device-availability surface. Mirrors the
//  CameraAccess sample's WearablesViewModel. Registration (linking the app to the
//  Meta AI companion app) must complete before any DeviceSession can be created.
//

import MWDATCore
import Observation
import SwiftUI

@Observable
@MainActor
final class WearablesManager {
    private(set) var devices: [DeviceIdentifier]
    private(set) var registrationState: RegistrationState
    var showError = false
    var errorMessage = ""

    @ObservationIgnored private let wearables: WearablesInterface
    @ObservationIgnored private var registrationTask: Task<Void, Never>?
    @ObservationIgnored private var deviceStreamTask: Task<Void, Never>?

    init(wearables: WearablesInterface) {
        self.wearables = wearables
        self.devices = wearables.devices
        self.registrationState = wearables.registrationState

        registrationTask = Task { [weak self] in
            guard let self else { return }
            for await state in wearables.registrationStateStream() {
                self.registrationState = state
            }
        }
        deviceStreamTask = Task { [weak self] in
            guard let self else { return }
            for await devices in wearables.devicesStream() {
                self.devices = devices
            }
        }
    }

    isolated deinit {
        registrationTask?.cancel()
        deviceStreamTask?.cancel()
    }

    var isRegistered: Bool { registrationState == .registered }

    var isConnecting: Bool { registrationState == .registering }

    /// Human-readable registration state for the UI.
    var registrationLabel: String {
        switch registrationState {
        case .registered: return "Connected"
        case .registering: return "Connecting…"
        default: return String(describing: registrationState).capitalized
        }
    }

    /// Name of the first known device, if any.
    var primaryDeviceName: String? {
        guard let id = devices.first else { return nil }
        return wearables.deviceForIdentifier(id)?.nameOrId()
    }

    func connect() {
        guard registrationState != .registering else { return }
        Task { @MainActor in
            do {
                try await wearables.startRegistration()
            } catch let error as RegistrationError {
                show(error.description)
            } catch {
                show(error.localizedDescription)
            }
        }
    }

    func disconnect() {
        Task { @MainActor in
            do {
                try await wearables.startUnregistration()
            } catch let error as UnregistrationError {
                show(error.description)
            } catch {
                show(error.localizedDescription)
            }
        }
    }

    private func show(_ message: String) {
        errorMessage = message
        showError = true
    }
}
