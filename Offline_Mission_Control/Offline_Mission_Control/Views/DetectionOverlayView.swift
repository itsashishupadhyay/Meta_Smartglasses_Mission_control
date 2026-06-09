//
//  DetectionOverlayView.swift
//  Offline_Mission_Control
//
//  The phone-side live view: the glasses camera frame with bounding boxes drawn on top.
//

import SwiftUI

struct DetectionOverlayView: View {
    let image: UIImage?
    let detections: [Detection]
    var highlightedLabels: Set<String> = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                    BoundingBoxLayer(
                        detections: detections,
                        imageSize: image.size,
                        containerSize: geo.size,
                        highlightedLabels: highlightedLabels
                    )
                } else {
                    placeholder
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "viewfinder")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            VStack(spacing: 4) {
                Text("Camera feed inactive")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                Text("Start detection to stream the glasses camera.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
    }
}
