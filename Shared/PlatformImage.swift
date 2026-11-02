//
//  PlatformImage.swift
//  VocaGrande
//
//  Created by Troy Mulder on 11/1/26.
//

import Foundation

#if canImport(AppKit)
import AppKit

/// The image type of whichever platform is building: `NSImage` on the Mac,
/// `UIImage` on the iPhone. Lets shared code such as `Message` carry an image
/// without knowing which.
typealias PlatformImage = NSImage

extension NSImage {
    /// The image as PNG, at its full pixel size.
    func encodedPNG() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
#else
import UIKit

typealias PlatformImage = UIImage

extension UIImage {
    /// The image as PNG, at its full pixel size.
    func encodedPNG() -> Data? {
        pngData()
    }
}
#endif
