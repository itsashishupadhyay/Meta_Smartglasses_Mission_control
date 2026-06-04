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
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                    Text(detection.displayText)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(color)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .fixedSize()
                        .offset(y: -15)
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
