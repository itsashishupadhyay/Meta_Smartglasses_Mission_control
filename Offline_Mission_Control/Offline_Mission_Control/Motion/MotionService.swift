//
//  MotionService.swift
//  Offline_Mission_Control
//
//  Phone IMU via Core Motion. The Meta Wearables Device Access Toolkit does NOT expose
//  the glasses' IMU in the current Developer Preview, so "IMU data" is sourced from the
//  iPhone. This is isolated behind a small surface so a glasses-IMU source could replace
//  it later if Meta exposes one.
//

import CoreMotion
import Foundation
import Observation

struct IMUSample: Sendable, Equatable {
    var roll: Double = 0      // radians
    var pitch: Double = 0
    var yaw: Double = 0
    var rotationRate = Vector3()
    var userAcceleration = Vector3()
    var timestamp: TimeInterval = 0
}

struct Vector3: Sendable, Equatable {
    var x: Double = 0
    var y: Double = 0
    var z: Double = 0
}

@Observable
@MainActor
final class MotionService {
    private(set) var sample = IMUSample()
    private(set) var isAvailable: Bool
    private(set) var isRunning = false

    @ObservationIgnored private let manager = CMMotionManager()

    init() {
        isAvailable = CMMotionManager().isDeviceMotionAvailable
    }

    func start(updateHz: Double = 30) {
        guard manager.isDeviceMotionAvailable, !isRunning else { return }
        manager.deviceMotionUpdateInterval = 1.0 / updateHz
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            self.sample = IMUSample(
                roll: m.attitude.roll,
                pitch: m.attitude.pitch,
                yaw: m.attitude.yaw,
                rotationRate: Vector3(x: m.rotationRate.x, y: m.rotationRate.y, z: m.rotationRate.z),
                userAcceleration: Vector3(
                    x: m.userAcceleration.x,
                    y: m.userAcceleration.y,
                    z: m.userAcceleration.z
                ),
                timestamp: m.timestamp
            )
        }
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        manager.stopDeviceMotionUpdates()
        isRunning = false
    }

    /// Degrees helper for display.
    static func deg(_ radians: Double) -> Int {
        Int((radians * 180 / .pi).rounded())
    }
}
