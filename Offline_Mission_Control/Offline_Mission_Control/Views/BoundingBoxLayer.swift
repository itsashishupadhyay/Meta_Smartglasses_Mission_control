//
//  BoundingBoxLayer.swift
//  Offline_Mission_Control
//
//  Draws detection boxes + labels over the displayed camera frame. Vision boxes are
//  normalized with a bottom-left origin, so we flip Y and map into the letterboxed image rect.
//  Boxes whose label is in `highlightedLabels` (the active mission task's object trigger) are
//  drawn thicker/accented so the operator can't miss the object they need.
//

import SwiftUI

struct BoundingBoxLayer: View {
    let detections: [Detection]
    let imageSize: CGSize
    let containerSize: CGSize
    var highlightedLabels: Set<String> = []

    var body: some View {
        let fitted = AspectFit.rect(imageSize: imageSize, in: containerSize)
        ZStack(alignment: .topLeading) {
            ForEach(detections) { detection in
                let rect = mapped(detection.boundingBox, in: fitted)
                let isTarget = highlightedLabels.contains(detection.label.lowercased())
                let color = isTarget ? Theme.accent : DetectionPalette.color(for: detection.label)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: isTarget ? 9 : 7, style: .continuous)
                        .stroke(color, lineWidth: isTarget ? 5 : 2.5)
                        .frame(width: rect.width, height: rect.height)
                        .shadow(color: color.opacity(isTarget ? 0.9 : 0.7), radius: isTarget ? 9 : 5)
                    label(for: detection, color: color, isTarget: isTarget)
                        .fixedSize()
                        .offset(y: -17)
                }
                .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func label(for detection: Detection, color: Color, isTarget: Bool) -> some View {
        HStack(spacing: 4) {
            if isTarget { Image(systemName: "scope").font(.system(size: 9, weight: .bold)) }
            Text(isTarget ? "TARGET · \(detection.displayText)" : detection.displayText)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(isTarget ? Theme.onAccent : .white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color, in: Capsule())
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
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
