//
//  TextSelection.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/1/26.
//

import SwiftUI

/// One piece of text captured out of the book, in its various stages. `id` exists
/// so the sidebar's list can tell two identical captures apart.
struct TextSelection: Identifiable {
    let id = UUID()

    /// Exactly what came out of the book, OCR warts and all.
    let text: String

    /// The API's tidied version: spacing, accents, and mangled characters fixed,
    /// with the author's wording untouched. Empty until it has been cleaned.
    var cleanedText: String = ""

    /// Set when the capture was made by dragging a rectangle rather than
    /// selecting text; nil otherwise.
    var selectedImage: Image?
}
