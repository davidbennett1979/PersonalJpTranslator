//
//  OpenAIClient.swift
//  PersonalJpTranslator
//
//  Created by Codex on 11/14/25.
//

import Foundation

protocol OpenAIClientProtocol {
    func sendChat(messages: [ChatMessage]) async throws -> String
}

struct OpenAIClient: OpenAIClientProtocol {
    private let session: URLSession
    private let model: String

    init(session: URLSession = .shared, model: String = "gpt-4o-mini") {
        self.session = session
        self.model = model
    }

    func sendChat(messages: [ChatMessage]) async throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
            throw OpenAIClientError.missingAPIKey
        }

        let requestBody = ChatRequest(model: model,
                                      messages: messages.map(OpenAIMessage.init),
                                      temperature: 0.7)
        let requestData = try JSONEncoder().encode(requestBody)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIClientError.server(statusCode: httpResponse.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw OpenAIClientError.emptyResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ChatRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String

    init(from message: ChatMessage) {
        self.role = message.role.rawValue
        self.content = message.text
    }
}

private struct ChatResponse: Codable {
    struct Choice: Codable {
        struct ChoiceMessage: Codable {
            let role: String
            let content: String
        }

        let index: Int
        let message: ChoiceMessage
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }

    let choices: [Choice]
}

enum OpenAIClientError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case server(statusCode: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing OpenAI API Key. Please set OPENAI_API_KEY in your environment."
        case .invalidResponse:
            return "Received an invalid response from the OpenAI API."
        case .server(let status, let message):
            return "OpenAI API error (\(status)): \(message)"
        case .emptyResponse:
            return "The OpenAI API returned an empty response."
        }
    }
}
