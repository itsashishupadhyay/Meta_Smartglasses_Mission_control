//
//  DetectionHUD.swift
//  Offline_Mission_Control
//
//  Builds the templated card shown on the Ray-Ban Display glasses. Imports ONLY MWDATDisplay
//  (no SwiftUI) so the DSL names Text/FlexBox aren't ambiguous, per the SDK's display guidance.
//  Each `send` replaces the previous card, so we re-send this when the detection summary changes.
//

import CoreFoundation
import MWDATDisplay

enum DetectionHUD {
    /// A compact detection summary card for the heads-up display.
    static func card(summaryLine: String, objectCount: Int) -> FlexBox {
        FlexBox(direction: .column, spacing: 10) {
            Text("Object Detection", style: .heading)
            Text(summaryLine, style: .body)
            Text(
                objectCount == 1 ? "1 object in view" : "\(objectCount) objects in view",
                style: .meta,
                color: .secondary
            )
        }
        .padding(24)
        .background(.card)
    }
}
