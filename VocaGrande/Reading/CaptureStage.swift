//
//  CaptureStage.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/1/26.
//

import Foundation

/// Which version of a capture a row is showing: what came out of the book,
/// the image it was taken from, or the cleaned-up text from the API.
enum CaptureStage: CaseIterable, Identifiable {
    case original
    case image
    case cleaned

    var id: Self { self }

    var symbol: String {
        switch self {
        case .original: "doc.plaintext"
        case .image: "photo"
        case .cleaned: "sparkles"
        }
    }

    var label: String {
        switch self {
        case .original: "Original text"
        case .image: "Captured image"
        case .cleaned: "Cleaned text"
        }
    }
}
