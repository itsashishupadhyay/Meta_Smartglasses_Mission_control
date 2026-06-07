//
//  BoundingBoxLayer.swift
//  Offline_Mission_Control
//
//  Draws detection boxes + labels over the displayed camera frame. Vision boxes are
//  normalized with a bottom-left origin, so we flip Y and map into the letterboxed image rect.
//

import SwiftUI

struct BoundingBoxLayer: View {
    let detections: [Detection]
    let imageSize: CGSize
    let containerSize: CGSize

    var body: some View {
        let fitted = AspectFit.rect(imageSize: imageSize, in: containerSize)
        ZStack(alignment: .topLeading) {
            ForEach(detections) { detection in
                let rect = mapped(detection.boundingBox, in: fitted)
                let color = DetectionPalette.color(for: detection.label)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(color, lineWidth: 2.5)
                        .frame(width: rect.width, height: rect.height)
                        .shadow(color: color.opacity(0.7), radius: 5)
                    Text(detection.displayText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color, in: Capsule())
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .fixedSize()
                        .offset(y: -17)
                }
                .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func mapped(_ box: CGRect, in fitted: CGRect) -> CGRect {
        CGRect(
            x: fitted.minX + box.minX * fitted.width,
            y: fitted.minY + (1 - box.maxY) * fitted.height, // flip bottom-left -> top-left
            width: box.width * fitted.width,
            height: box.height * fitted.height
        )
    }
}
