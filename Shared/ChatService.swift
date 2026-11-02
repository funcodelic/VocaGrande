//
//  ChatService.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/1/26.
//

import Foundation

/// Sends messages to OpenAI's Responses API and hands back the reply text.
///
/// This is the only type that knows about HTTP and the API's JSON. Callers deal
/// in `Message`s going in and a `String` coming out. Anything that goes wrong is
/// a thrown `ChatError`, or a `URLError` when the network itself is the problem.
struct ChatService {

    /// The model every request goes to.
    static let model = "gpt-5.6-terra"

    private static let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    /// Sends the messages and returns the assistant's reply, trimmed.
    func send(_ messages: [Message]) async throws -> String {
        let request = try makeURLRequest(for: messages)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkForAPIError(in: data, response: response)
        return try Self.replyText(in: data)
    }

    // MARK: - Request

    /// The key lives in the git-ignored Config.xcconfig. The build copies it into
    /// Info.plist as OPENAI_API_KEY, which is where the app reads it from.
    func loadAPIKey() -> String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
              !key.isEmpty else { return nil }
        return key
    }

    private func makeURLRequest(for messages: [Message]) throws -> URLRequest {
        guard let key = loadAPIKey() else { throw ChatError.missingAPIKey }

        let input = try messages.map { try InputMessage($0) }
        let body = RequestBody(model: Self.model, input: input)

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        return request
    }

    // MARK: - Response

    /// The API reports failures as an `error` object, usually with a non-2xx
    /// status. Either one on its own is enough to give up on.
    private static func checkForAPIError(in data: Data, response: URLResponse) throws {
        if let body = try? JSONDecoder().decode(ErrorBody.self, from: data),
           let message = body.error?.message {
            throw ChatError.api(message)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ChatError.api("HTTP \(http.statusCode) from the API.")
        }
    }

    /// The reply is the text of every `output_text` part, in order. Other output
    /// items, such as reasoning, carry no content and are skipped.
    private static func replyText(in data: Data) throws -> String {
        let body = try JSONDecoder().decode(ResponseBody.self, from: data)
        let text = body.output
            .flatMap { $0.content ?? [] }
            .filter { $0.type == "output_text" }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ChatError.emptyReply }
        return text
    }

    // MARK: - Wire format
    //
    // What the API's JSON looks like, on the way out and on the way back. Kept
    // private: nobody outside builds a request or reads a response.

    private struct RequestBody: Encodable {
        let model: String
        let input: [InputMessage]
    }

    private struct InputMessage: Encodable {
        let role: String
        let content: [ContentPart]

        init(_ message: Message) throws {
            role = message.role.rawValue
            content = try message.content.map { try ContentPart($0) }
        }
    }

    /// `Message.Content` as the API spells it: `input_text` with its text, or
    /// `input_image` with a data URL. Images go as PNG at high detail, since the
    /// whole point is reading small print.
    private enum ContentPart: Encodable {
        case text(String)
        case image(dataURL: String)

        init(_ content: Message.Content) throws {
            switch content {
            case .text(let string):
                self = .text(string)
            case .image(let image):
                guard let png = image.encodedPNG() else { throw ChatError.unreadableImage }
                self = .image(dataURL: "data:image/png;base64," + png.base64EncodedString())
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type, text, detail
            case imageURL = "image_url"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let string):
                try container.encode("input_text", forKey: .type)
                try container.encode(string, forKey: .text)
            case .image(let dataURL):
                try container.encode("input_image", forKey: .type)
                try container.encode(dataURL, forKey: .imageURL)
                try container.encode("high", forKey: .detail)
            }
        }
    }

    private struct ResponseBody: Decodable {
        struct Output: Decodable {
            struct Content: Decodable {
                let type: String
                let text: String?
            }
            let type: String
            let content: [Content]?
        }
        let output: [Output]
    }

    private struct ErrorBody: Decodable {
        struct APIError: Decodable {
            let message: String
        }
        let error: APIError?
    }
}
