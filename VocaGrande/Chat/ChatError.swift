//
//  ChatError.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/1/26.
//

import Foundation

/// The ways a request to the model fails, beyond what URLSession itself throws
/// when there is no network. Each carries what a person needs to know.
enum ChatError: LocalizedError {

    /// OPENAI_API_KEY isn't in the app's Info.plist. It gets there from the
    /// git-ignored Config.xcconfig; see `ChatService.loadAPIKey`.
    case missingAPIKey

    /// An image in a message couldn't be encoded as PNG to send.
    case unreadableImage

    /// The API answered with an error rather than a reply. Carries its message.
    case api(String)

    /// The API answered, but with no text in the reply.
    case emptyReply

    /// The API answered, but not in the form asked for: text where the request
    /// wanted JSON, or JSON of another shape.
    case malformedReply

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "No OpenAI API key. Add OPENAI_API_KEY to Config.xcconfig and Info.plist."
        case .unreadableImage:
            "The image couldn't be encoded to send."
        case .api(let message):
            message
        case .emptyReply:
            "Chat replied with no text."
        case .malformedReply:
            "Chat replied in a form the app couldn't read."
        }
    }
}
