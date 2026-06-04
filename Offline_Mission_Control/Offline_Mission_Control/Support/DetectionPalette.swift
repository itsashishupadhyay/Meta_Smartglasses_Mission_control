//
//  DetectionPalette.swift
//  Offline_Mission_Control
//
//  Stable per-label colors for bounding boxes (same label -> same color across frames).
//

import SwiftUI

enum DetectionPalette {
    private static let colors: [Color] = [
        .red, .green, .blue, .orange, .purple, .pink, .teal, .yellow, .mint, .cyan, .indigo
    ]

    static func color(for label: String) -> Color {
        var hash = 5381
        for byte in label.utf8 { hash = ((hash << 5) &+ hash) &+ Int(byte) }
        return colors[abs(hash) % colors.count]
    }
}
