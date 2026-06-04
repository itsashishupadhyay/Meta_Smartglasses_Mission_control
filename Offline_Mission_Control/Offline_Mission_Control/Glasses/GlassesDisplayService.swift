//
//  GlassesDisplayService.swift
//  Offline_Mission_Control
//
//  Pushes a templated HUD card to Meta Ray-Ban Display glasses. The DAT Display API is a
//  declarative DSL (FlexBox/Text/Icon/...), NOT a pixel canvas — so we render a live-updating
//  detection *summary* card here, while the full live frame + bounding boxes are drawn on the
//  phone. Distilled from the DisplayAccess sample's DisplayViewModel (pending-action pattern:
//  a queued send auto-fires once the display session reaches `.started`).
//

import MWDATCore
import MWDATDisplay
import Observation
import SwiftUI

@Observable
@MainActor
final class GlassesDisplayService {
    private(set) var isConnected = false
    var errorMessage: String?

    @ObservationIgnored private let wearables: WearablesInterface
    @ObservationIgnored private var deviceSelector: AutoDeviceSelector
    @ObservationIgnored private var deviceSession: DeviceSession?
    @ObservationIgnored private var display: Display?
    @ObservationIgnored private var stateToken: AnyListenerToken?
    @ObservationIgnored private var coreStateTask: Task<Void, Never>?
    @ObservationIgnored private var sessionErrorTask: Task<Void, Never>?
    @ObservationIgnored private var displayStateTask: Task<Void, Never>?
    @ObservationIgnored private var displayStateContinuation: AsyncStream<DisplayState>.Continuation?
    @ObservationIgnored private var pendingAction: (() async -> Void)?

    init(wearables: WearablesInterface) {
        self.wearables = wearables
        self.deviceSelector = AutoDeviceSelector(wearables: wearables, filter: { $0.supportsDisplay() })
    }

    isolated deinit {
        stateToken = nil
        coreStateTask?.cancel()
        sessionErrorTask?.cancel()
        displayStateTask?.cancel()
    }

    /// Send a view to the glasses, auto-attaching if needed (queued until `.started`).
    func send(_ view: some DisplayableView) async {
        if let display, isConnected {
            await doSend(view, on: display)
            return
        }
        let queued = view
        pendingAction = { [weak self] in
            guard let self, let cap = self.display else { return }
            await self.doSend(queued, on: cap)
        }
        if display == nil {
            await attach()
        }
    }

    func detach() async {
        stateToken = nil
        displayStateContinuation?.finish()
        displayStateContinuation = nil
        displayStateTask?.cancel()
        displayStateTask = nil
        await display?.stop()
        display = nil
        coreStateTask?.cancel()
        coreStateTask = nil
        sessionErrorTask?.cancel()
        sessionErrorTask = nil
        deviceSession?.stop()
        deviceSession = nil
        isConnected = false
        pendingAction = nil
    }

    // MARK: - Private

    private func doSend(_ view: some DisplayableView, on capability: Display) async {
        do {
            try await capability.send(view)
        } catch {
            errorMessage = (error as? DisplayError)?.description ?? error.localizedDescription
        }
    }

    private func attach() async {
        guard display == nil else { return }
        do {
            let session = try wearables.createSession(deviceSelector: deviceSelector)
            deviceSession = session

            let stateStream = session.stateStream()
            let errorStream = session.errorStream()
            coreStateTask = Task { [weak self] in
                for await state in stateStream {
                    guard let self, !Task.isCancelled else { return }
                    switch state {
                    case .started:
                        await self.setupDisplay(on: session)
                    case .stopping, .stopped:
                        self.isConnected = false
                        self.display = nil
                    default:
                        break
                    }
                }
            }
            sessionErrorTask = Task { [weak self] in
                for await error in errorStream {
                    guard let self, !Task.isCancelled else { return }
                    self.errorMessage = error.localizedDescription
                }
            }
            try session.start()
        } catch DeviceSessionError.datAppOnTheGlassesUpdateRequired {
            errorMessage = DeviceSessionError.datAppOnTheGlassesUpdateRequired.localizedDescription
        } catch {
            errorMessage = "Failed to create display session: \(error.localizedDescription)"
        }
    }

    private func setupDisplay(on session: DeviceSession) async {
        guard display == nil else { return }
        do {
            let capability = try session.addDisplay()
            let (stream, continuation) = AsyncStream.makeStream(of: DisplayState.self)
            displayStateContinuation = continuation
            stateToken = capability.statePublisher.listen { state in
                continuation.yield(state)
            }
            displayStateTask = Task { [weak self] in
                for await state in stream {
                    guard let self, !Task.isCancelled else { return }
                    switch state {
                    case .started:
                        self.isConnected = true
                        if let action = self.pendingAction {
                            self.pendingAction = nil
                            await action()
                        }
                    case .stopping:
                        self.isConnected = false
                    case .stopped:
                        self.isConnected = false
                        self.stateToken = nil
                        self.displayStateContinuation?.finish()
                        self.displayStateContinuation = nil
                        self.display = nil
                        self.coreStateTask?.cancel()
                        self.coreStateTask = nil
                        self.deviceSession?.stop()
                        self.deviceSession = nil
                    case .starting:
                        break
                    }
                }
            }
            await capability.start()
            display = capability
        } catch {
            errorMessage = "Failed to start display: \(error.localizedDescription)"
        }
    }
}
