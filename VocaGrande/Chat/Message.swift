//
//  Message.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/1/26.
//

import AppKit
import Foundation

/// One turn in what we send the model: who is speaking, and what they say. What
/// they say is a list of parts, because a message about an image is the text
/// saying what to do with it, and the image itself.
struct Message {

    /// Maps to the role the API expects. `developer` carries instructions that
    /// steer the reply without being part of the conversation itself.
    enum Role: String {
        case developer
        case user
        case assistant
    }

    /// One part of a message: it is text, or it is an image, never both. The API
    /// calls these content parts.
    enum Content {
        case text(String)
        case image(NSImage)
    }

    let role: Role
    let content: [Content]

    init(role: Role, content: [Content]) {
        self.role = role
        self.content = content
    }

    /// Instructions to the model, kept apart from the conversation.
    static func developer(_ text: String) -> Message {
        Message(role: .developer, content: [.text(text)])
    }

    /// What the user says, with an image after the text when there is one.
    static func user(_ text: String, image: NSImage? = nil) -> Message {
        var content: [Content] = [.text(text)]
        if let image {
            content.append(.image(image))
        }
        return Message(role: .user, content: content)
    }
}
