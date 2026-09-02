//
//  CaptureActivity.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/1/26.
//

import Foundation

/// What the API is doing for a capture right now, or how its last job ended.
/// Session-only: `BookPdfController` keeps one per item, and the row shows it
/// in place of the text that isn't there yet.
enum CaptureActivity: Equatable {

    /// The image is being read into `selectionText`.
    case reading

    /// `selectionText` is being cleaned into `cleanedText`.
    case cleaning

    /// `cleanedText` is being translated into `translatedText`.
    case translating

    /// The last read, clean or translation failed, with the reason to show.
    case failed(String)
}
