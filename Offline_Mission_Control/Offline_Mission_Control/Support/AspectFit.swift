//
//  AspectFit.swift
//  Offline_Mission_Control
//
//  Computes the letterboxed rect of an aspect-fit image inside a container, so bounding
//  boxes can be mapped onto exactly the pixels the image occupies on screen.
//

import CoreGraphics

enum AspectFit {
    static func rect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(
            x: (container.width - width) / 2,
            y: (container.height - height) / 2,
            width: width,
            height: height
        )
    }
}
