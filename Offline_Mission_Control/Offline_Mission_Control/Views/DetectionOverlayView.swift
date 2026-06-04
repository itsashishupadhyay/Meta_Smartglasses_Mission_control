//
//  DetectionOverlayView.swift
//  Offline_Mission_Control
//
//  The phone-side live view: the glasses camera frame with bounding boxes drawn on top.
//  Shown in BOTH modes (it's the primary view for non-display glasses, and a monitor for
//  display glasses).
//

import SwiftUI

struct DetectionOverlayView: View {
    let image: UIImage?
    let detections: [Detection]

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
                        containerSize: geo.size
                    )
                } else {
                    ContentUnavailableView(
                        "No camera feed",
                        systemImage: "video.slash",
                        description: Text("Start detection to stream the glasses camera.")
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
    }
}
