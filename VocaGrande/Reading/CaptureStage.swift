//
//  CaptureStage.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/1/26.
//

import Foundation

/// Which version of a capture a row is showing: what came out of the book,
/// the image it was taken from, the cleaned-up text from the API, or its
/// English translation.
enum CaptureStage: CaseIterable, Identifiable {
    case original
    case image
    case cleaned
    case translated

    var id: Self { self }

    var symbol: String {
        switch self {
        case .original: "doc.plaintext"
        case .image: "photo"
        case .cleaned: "sparkles"
        case .translated: "arrow.right"
        }
    }

    var label: String {
        switch self {
        case .original: "Original text"
        case .image: "Captured image"
        case .cleaned: "Cleaned text"
        case .translated: "English translation"
        }
    }
}
